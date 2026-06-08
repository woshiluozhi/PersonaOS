#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

WITH_BUILD=0
WITH_TESTS=0

for arg in "$@"; do
  case "$arg" in
    --with-build)
      WITH_BUILD=1
      ;;
    --with-tests)
      WITH_TESTS=1
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/verify_app_store_readiness.sh [--with-build] [--with-tests]

Static checks run by default:
  - Required App Store docs exist.
  - App icon is a 1024 x 1024 PNG without alpha.
  - Privacy manifest is valid and declares no tracking.
  - Project uses the production bundle identifiers.
  - App target is iPhone portrait only.
  - App target declares no non-exempt encryption.
  - Staged changes do not include local signing team IDs.
  - Source does not contain likely real OpenAI API keys.

Optional:
  --with-build  Run build-for-testing and Release generic iOS build.
  --with-tests  Run the full iPhone 17 simulator test suite.
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

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is available"
  else
    fail "$1 is not available"
  fi
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
require_file "PRIVACY_POLICY_DRAFT.md"
require_file "$PROJECT_FILE"
require_file "$PRIVACY_MANIFEST"
require_file "$APP_ICON_CONTENTS"
require_file "$APP_ICON_FILE"

echo
echo "== Tooling =="
require_command plutil
require_command sips
require_command git

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
  require_grep 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' "$PROJECT_FILE" "App icon asset is wired to target"
  require_grep 'PrivacyInfo\.xcprivacy' "$PROJECT_FILE" "Privacy manifest is wired to target"
  require_grep 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;' "$PROJECT_FILE" "iPhone orientation is portrait"
  require_grep 'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;' "$PROJECT_FILE" "App declares no non-exempt encryption"
  require_grep 'TARGETED_DEVICE_FAMILY = 1;' "$PROJECT_FILE" "App target is iPhone family"
fi

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
require_grep 'Data Sent to OpenAI' "PRIVACY_POLICY_DRAFT.md" "Privacy policy draft explains OpenAI data sharing"

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
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "App Store readiness verification passed."
  exit 0
fi

echo "App Store readiness verification failed with $failures issue(s)." >&2
exit 1
