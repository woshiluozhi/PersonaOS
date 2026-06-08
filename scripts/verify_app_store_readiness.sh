#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

WITH_BUILD=0
WITH_TESTS=0
WITH_SCREENSHOTS=0

for arg in "$@"; do
  case "$arg" in
    --with-build)
      WITH_BUILD=1
      ;;
    --with-tests)
      WITH_TESTS=1
      ;;
    --with-screenshots)
      WITH_SCREENSHOTS=1
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/verify_app_store_readiness.sh [--with-build] [--with-tests] [--with-screenshots]

Static checks run by default:
  - Required App Store docs exist.
  - App Store submission package exists.
  - Public support/privacy page drafts exist.
  - App icon is a 1024 x 1024 PNG without alpha.
  - Privacy manifest is valid and declares no tracking.
  - Project uses the production bundle identifiers.
  - Release metadata has display name, version, build, category, launch screen, and deployment target.
  - App target is iPhone portrait only.
  - App target declares no non-exempt encryption.
  - App target does not declare protected permissions, background modes, or entitlements.
  - Screenshot plan and capture helper exist.
  - Staged changes do not include local signing team IDs.
  - Source does not contain likely real OpenAI API keys.

Optional:
  --with-build  Run build-for-testing and Release generic iOS build.
  --with-tests  Run the full iPhone 17 simulator test suite.
  --with-screenshots
                Validate the complete App Store screenshot set in BuildLogs/AppStoreScreenshots.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

failures=0

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  if [[ -f "$1" ]]; then
    pass "$1 exists"
  else
    fail "$1 is missing"
  fi
}

require_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  if grep -Eq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_absent_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is available"
  else
    fail "$1 is not available"
  fi
}

plist_raw() {
  local file="$1"
  local key="$2"

  plutil -extract "$key" raw -o - "$file" 2>/dev/null || true
}

PROJECT_FILE="PersonaOS.xcodeproj/project.pbxproj"
PRIVACY_MANIFEST="PersonaOS/Resources/PrivacyInfo.xcprivacy"
APP_ICON_CONTENTS="PersonaOS/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json"
APP_ICON_FILE="PersonaOS/Resources/Assets.xcassets/AppIcon.appiconset/PersonaOS-AppIcon-1024.png"

echo "== Required files =="
require_file "README.md"
require_file "APP_STORE_READINESS.md"
require_file "APP_STORE_METADATA.md"
require_file "APP_STORE_PRIVACY_ANSWERS.md"
require_file "APP_STORE_AGE_RATING.md"
require_file "APP_STORE_PUBLIC_PAGES.md"
require_file "PRIVACY_POLICY_DRAFT.md"
require_file "APP_STORE_SCREENSHOTS.md"
require_file "APP_STORE_SUBMISSION_PACKAGE.md"
require_file "docs/index.html"
require_file "docs/privacy.html"
require_file "docs/support.html"
require_file "scripts/capture_app_store_screenshot.sh"
require_file "scripts/validate_app_store_screenshots.sh"
require_file "$PROJECT_FILE"
require_file "$PRIVACY_MANIFEST"
require_file "$APP_ICON_CONTENTS"
require_file "$APP_ICON_FILE"

echo
echo "== Tooling =="
require_command plutil
require_command sips
require_command git
require_command xcrun

echo
echo "== App icon =="
if [[ -f "$APP_ICON_CONTENTS" ]]; then
  icon_size="$(plutil -extract images.0.size raw -o - "$APP_ICON_CONTENTS" 2>/dev/null || true)"
  icon_filename="$(plutil -extract images.0.filename raw -o - "$APP_ICON_CONTENTS" 2>/dev/null || true)"

  [[ "$icon_size" == "1024x1024" ]] && pass "App icon catalog declares 1024x1024" || fail "App icon catalog does not declare 1024x1024"
  [[ "$icon_filename" == "PersonaOS-AppIcon-1024.png" ]] && pass "App icon catalog points to PersonaOS-AppIcon-1024.png" || fail "App icon catalog points to unexpected file"
fi

if [[ -f "$APP_ICON_FILE" ]]; then
  icon_width="$(sips -g pixelWidth "$APP_ICON_FILE" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  icon_height="$(sips -g pixelHeight "$APP_ICON_FILE" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
  icon_alpha="$(sips -g hasAlpha "$APP_ICON_FILE" 2>/dev/null | awk '/hasAlpha/ {print $2}')"

  [[ "$icon_width" == "1024" && "$icon_height" == "1024" ]] && pass "App icon PNG is 1024 x 1024" || fail "App icon PNG is not 1024 x 1024"
  [[ "$icon_alpha" == "no" ]] && pass "App icon PNG has no alpha channel" || fail "App icon PNG has an alpha channel"
fi

echo
echo "== Privacy manifest =="
if [[ -f "$PRIVACY_MANIFEST" ]]; then
  if plutil -lint "$PRIVACY_MANIFEST" >/dev/null; then
    pass "Privacy manifest plist is valid"
  else
    fail "Privacy manifest plist is invalid"
  fi

  tracking="$(plutil -extract NSPrivacyTracking raw -o - "$PRIVACY_MANIFEST" 2>/dev/null || true)"
  collected_name="$(plutil -extract NSPrivacyCollectedDataTypes.0.NSPrivacyCollectedDataType raw -o - "$PRIVACY_MANIFEST" 2>/dev/null || true)"
  collected_content="$(plutil -extract NSPrivacyCollectedDataTypes.1.NSPrivacyCollectedDataType raw -o - "$PRIVACY_MANIFEST" 2>/dev/null || true)"

  [[ "$tracking" == "false" ]] && pass "Privacy manifest declares no tracking" || fail "Privacy manifest does not declare no tracking"
  [[ "$collected_name" == "NSPrivacyCollectedDataTypeName" ]] && pass "Privacy manifest declares user name data" || fail "Privacy manifest is missing user name data declaration"
  [[ "$collected_content" == "NSPrivacyCollectedDataTypeOtherUserContent" ]] && pass "Privacy manifest declares user-generated content" || fail "Privacy manifest is missing user-generated content declaration"
fi

echo
echo "== Xcode project metadata =="
if [[ -f "$PROJECT_FILE" ]]; then
  require_grep 'PRODUCT_BUNDLE_IDENTIFIER = com\.woshiluozhi\.personaos;' "$PROJECT_FILE" "App bundle identifier is com.woshiluozhi.personaos"
  require_grep 'PRODUCT_BUNDLE_IDENTIFIER = com\.woshiluozhi\.personaos\.tests;' "$PROJECT_FILE" "Test bundle identifier is com.woshiluozhi.personaos.tests"
  require_grep 'INFOPLIST_KEY_CFBundleDisplayName = PersonaOS;' "$PROJECT_FILE" "App display name is PersonaOS"
  require_grep 'MARKETING_VERSION = 1\.0;' "$PROJECT_FILE" "Marketing version is set to 1.0"
  require_grep 'CURRENT_PROJECT_VERSION = 1;' "$PROJECT_FILE" "Build number is set to 1"
  require_grep 'INFOPLIST_KEY_LSApplicationCategoryType = "public\.app-category\.productivity";' "$PROJECT_FILE" "App category is Productivity"
  require_grep 'INFOPLIST_KEY_UILaunchScreen_Generation = YES;' "$PROJECT_FILE" "Generated launch screen is enabled"
  require_grep 'IPHONEOS_DEPLOYMENT_TARGET = 17\.0;' "$PROJECT_FILE" "iOS deployment target is 17.0"
  require_grep 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' "$PROJECT_FILE" "App icon asset is wired to target"
  require_grep 'PrivacyInfo\.xcprivacy' "$PROJECT_FILE" "Privacy manifest is wired to target"
  require_grep 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;' "$PROJECT_FILE" "iPhone orientation is portrait"
  require_grep 'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;' "$PROJECT_FILE" "App declares no non-exempt encryption"
  require_grep 'TARGETED_DEVICE_FAMILY = 1;' "$PROJECT_FILE" "App target is iPhone family"
fi

echo
echo "== Permissions and capabilities =="
if [[ -f "$PROJECT_FILE" ]]; then
  require_absent_grep 'NS(Camera|Microphone|Contacts|Calendars|Health|PhotoLibrary|PhotoLibraryAdd|UserTracking)UsageDescription' "$PROJECT_FILE" "Project declares no unused protected permission usage strings"
  require_absent_grep 'NSLocation(WhenInUse|Always|AlwaysAndWhenInUse|UsageDescription)' "$PROJECT_FILE" "Project declares no location usage strings"
  require_absent_grep 'UIBackgroundModes' "$PROJECT_FILE" "Project declares no background modes"
  require_absent_grep 'CODE_SIGN_ENTITLEMENTS|SystemCapabilities|aps-environment|com\.apple\.developer\.healthkit' "$PROJECT_FILE" "Project declares no extra entitlements or capabilities"
fi

if git grep -nE 'NS(Camera|Microphone|Contacts|Calendars|Health|PhotoLibrary|PhotoLibraryAdd|UserTracking)UsageDescription|NSLocation(WhenInUse|Always|AlwaysAndWhenInUse|UsageDescription)|UIBackgroundModes|CODE_SIGN_ENTITLEMENTS|SystemCapabilities|aps-environment|com\.apple\.developer\.healthkit' -- PersonaOS PersonaOS.xcodeproj >/tmp/personaos-permission-scan.txt 2>/dev/null; then
  cat /tmp/personaos-permission-scan.txt >&2
  fail "Tracked app source declares protected permissions, background modes, or entitlements"
else
  pass "Tracked app source declares no protected permissions, background modes, or entitlements"
fi
rm -f /tmp/personaos-permission-scan.txt

echo
echo "== Repository safety =="
if git diff --cached -- "$PROJECT_FILE" | grep -q 'DEVELOPMENT_TEAM'; then
  fail "Staged project diff includes DEVELOPMENT_TEAM; keep local signing team IDs out of commits"
else
  pass "Staged project diff does not include DEVELOPMENT_TEAM"
fi

if git diff --cached -- "$PROJECT_FILE" | grep -q 'KBMLG24334'; then
  fail "Staged project diff includes local Team ID KBMLG24334"
else
  pass "Staged project diff does not include local Team ID"
fi

if git grep -nE 'sk-[A-Za-z0-9_-]{20,}' -- \
  ':!PersonaOS/Tests/OpenAIClientTests.swift' \
  ':!BuildLogs' \
  ':!DerivedData' >/tmp/personaos-secret-scan.txt 2>/dev/null; then
  cat /tmp/personaos-secret-scan.txt >&2
  fail "Repository contains strings that look like real OpenAI API keys"
else
  pass "No likely real OpenAI API keys found in tracked source"
fi
rm -f /tmp/personaos-secret-scan.txt

echo
echo "== App Store docs =="
require_grep 'Support URL: to be provided by the account owner' "APP_STORE_READINESS.md" "Readiness doc calls out missing Support URL"
require_grep 'Privacy Policy URL: to be provided by the account owner' "APP_STORE_READINESS.md" "Readiness doc calls out missing Privacy Policy URL"
require_grep 'OpenAI API Key' "APP_STORE_METADATA.md" "Metadata draft explains OpenAI API Key flow"
require_grep 'does not read other apps' "APP_STORE_METADATA.md" "Metadata draft explains privacy boundary"
require_grep 'Data type: Contact Info -> Name' "APP_STORE_PRIVACY_ANSWERS.md" "Privacy answers draft covers Name"
require_grep 'Data type: User Content -> Other User Content' "APP_STORE_PRIVACY_ANSWERS.md" "Privacy answers draft covers Other User Content"
require_grep 'Uses non-exempt encryption: No' "APP_STORE_PRIVACY_ANSWERS.md" "Privacy answers draft covers export compliance"
require_grep 'Expected Apple global rating: `4\+`' "APP_STORE_AGE_RATING.md" "Age rating draft suggests 4+"
require_grep 'Made for Kids: `No`' "APP_STORE_AGE_RATING.md" "Age rating draft does not mark Made for Kids"
require_grep 'Unrestricted Web Access \| No' "APP_STORE_AGE_RATING.md" "Age rating draft denies unrestricted web access"
require_grep 'Messaging and Chat \| No' "APP_STORE_AGE_RATING.md" "Age rating draft distinguishes AI chat from user messaging"
require_grep 'developer\.apple\.com/help/app-store-connect/manage-app-information/set-an-app-age-rating' "APP_STORE_AGE_RATING.md" "Age rating draft links Apple age rating setup reference"
require_grep 'https://woshiluozhi\.github\.io/PersonaOS/support\.html' "APP_STORE_PUBLIC_PAGES.md" "Public pages doc includes candidate Support URL"
require_grep 'https://woshiluozhi\.github\.io/PersonaOS/privacy\.html' "APP_STORE_PUBLIC_PAGES.md" "Public pages doc includes candidate Privacy Policy URL"
require_grep 'PersonaOS Privacy Policy' "docs/privacy.html" "Privacy HTML page has policy title"
require_grep 'Data Sent to OpenAI' "docs/privacy.html" "Privacy HTML page explains OpenAI data sharing"
require_grep 'PersonaOS Support' "docs/support.html" "Support HTML page has support title"
require_grep 'https://github\.com/woshiluozhi/PersonaOS/issues' "docs/support.html" "Support HTML page links support contact path"
require_grep 'Data Sent to OpenAI' "PRIVACY_POLICY_DRAFT.md" "Privacy policy draft explains OpenAI data sharing"
require_grep '01-home\.png' "APP_STORE_SCREENSHOTS.md" "Screenshot plan covers Home"
require_grep '06-settings-ai-privacy\.png' "APP_STORE_SCREENSHOTS.md" "Screenshot plan covers Settings privacy"
require_grep 'developer\.apple\.com/help/app-store-connect/reference/app-information/screenshot-specifications' "APP_STORE_SCREENSHOTS.md" "Screenshot plan links Apple screenshot specifications"
require_grep 'scripts/verify_app_store_readiness\.sh --with-build --with-tests' "APP_STORE_SUBMISSION_PACKAGE.md" "Submission package includes final engineering gate"
require_grep 'Support URL' "APP_STORE_SUBMISSION_PACKAGE.md" "Submission package calls out Support URL"
require_grep 'Privacy Policy URL' "APP_STORE_SUBMISSION_PACKAGE.md" "Submission package calls out Privacy Policy URL"
require_grep 'developer\.apple\.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app' "APP_STORE_SUBMISSION_PACKAGE.md" "Submission package links Apple submit app reference"

if [[ -x "scripts/capture_app_store_screenshot.sh" ]]; then
  pass "Screenshot capture helper is executable"
else
  fail "Screenshot capture helper is not executable"
fi

if [[ -x "scripts/validate_app_store_screenshots.sh" ]]; then
  pass "Screenshot validation helper is executable"
else
  fail "Screenshot validation helper is not executable"
fi

if [[ "$WITH_SCREENSHOTS" == "1" ]]; then
  echo
  echo "== Screenshot validation =="
  if scripts/validate_app_store_screenshots.sh; then
    pass "Complete App Store screenshot set passed validation"
  else
    fail "Complete App Store screenshot set failed validation"
  fi
fi

if [[ "$WITH_TESTS" == "1" ]]; then
  echo
  echo "== Full tests =="
  if xcodebuild -scheme PersonaOS -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData -parallel-testing-enabled NO test; then
    pass "Full iPhone 17 simulator tests passed"
  else
    fail "Full iPhone 17 simulator tests failed"
  fi
fi

if [[ "$WITH_BUILD" == "1" ]]; then
  echo
  echo "== Build verification =="
  if xcodebuild -scheme PersonaOS -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData build-for-testing; then
    pass "build-for-testing passed"
  else
    fail "build-for-testing failed"
  fi

  if xcodebuild -scheme PersonaOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build; then
    pass "Release generic iOS build passed"
  else
    fail "Release generic iOS build failed"
  fi

  echo
  echo "== Built Info.plist metadata =="
  DEBUG_INFO_PLIST="DerivedData/Build/Products/Debug-iphonesimulator/PersonaOS.app/Info.plist"
  RELEASE_INFO_PLIST="DerivedData/Build/Products/Release-iphoneos/PersonaOS.app/Info.plist"

  for info_plist in "$DEBUG_INFO_PLIST" "$RELEASE_INFO_PLIST"; do
    if [[ ! -f "$info_plist" ]]; then
      fail "$info_plist is missing"
      continue
    fi

    bundle_name="$(plist_raw "$info_plist" CFBundleDisplayName)"
    marketing_version="$(plist_raw "$info_plist" CFBundleShortVersionString)"
    build_number="$(plist_raw "$info_plist" CFBundleVersion)"
    category="$(plist_raw "$info_plist" LSApplicationCategoryType)"
    non_exempt_encryption="$(plist_raw "$info_plist" ITSAppUsesNonExemptEncryption)"

    [[ "$bundle_name" == "PersonaOS" ]] && pass "$info_plist display name is PersonaOS" || fail "$info_plist display name is unexpected"
    [[ "$marketing_version" == "1.0" ]] && pass "$info_plist marketing version is 1.0" || fail "$info_plist marketing version is unexpected"
    [[ "$build_number" == "1" ]] && pass "$info_plist build number is 1" || fail "$info_plist build number is unexpected"
    [[ "$category" == "public.app-category.productivity" ]] && pass "$info_plist category is Productivity" || fail "$info_plist category is unexpected"
    [[ "$non_exempt_encryption" == "false" ]] && pass "$info_plist declares no non-exempt encryption" || fail "$info_plist non-exempt encryption declaration is unexpected"
  done
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "App Store readiness verification passed."
  exit 0
fi

echo "App Store readiness verification failed with $failures issue(s)." >&2
exit 1
