#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

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

  if [[ -f "$file" ]] && grep -Eq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "== Automation state =="
require_file "automation/STATUS.md"
require_file "automation/BACKLOG.yaml"
require_file "automation/DECISIONS.yaml"
require_file "automation/RUN_LOG.md"
require_file "automation/RISK_REGISTER.md"
require_file "automation/HUMAN_GATES.md"
require_file "automation/APPSTORE_CHECKLIST.md"

require_grep '^product_target: macos_native$' "automation/DECISIONS.yaml" "Default product target is native macOS"
require_grep '^keep_existing_ios_target: true$' "automation/DECISIONS.yaml" "Existing iOS target is preserved"
require_grep '^local_mode_must_always_work: true$' "automation/DECISIONS.yaml" "Local AI mode remains mandatory"
require_grep '^third_party_sdks: disallow_by_default$' "automation/DECISIONS.yaml" "Third-party SDKs are disallowed by default"
require_grep '^rename_potential_ip_references: true$' "automation/DECISIONS.yaml" "Potential IP references are release-gated"
require_grep 'not_release_done' "automation/STATUS.md" "Status does not claim release done"
require_grep 'PersonaOSMac.*planned target' "automation/STATUS.md" "Status records missing macOS target"
require_grep 'MAC-001' "automation/BACKLOG.yaml" "Backlog includes macOS target planning"
require_grep 'PAGES-001' "automation/BACKLOG.yaml" "Backlog includes public pages deployment"
require_grep 'Final age rating answers' "automation/HUMAN_GATES.md" "Human gates include final age rating"
require_grep 'Signing and ASC credentials' "automation/HUMAN_GATES.md" "Human gates include signing credentials"

echo
echo "== Prompt and skill layer =="
require_file "prompts/MASTER_PROMPT.md"
require_file "prompts/TASK_INPUT_TEMPLATE.md"
require_file "prompts/SUBPROMPT_IMPLEMENT.md"
require_file "prompts/SUBPROMPT_TEST.md"
require_file "prompts/SUBPROMPT_UITEST.md"
require_file "prompts/SUBPROMPT_PACKAGE_SIGN.md"
require_file "prompts/SUBPROMPT_METADATA_PRIVACY.md"
require_file "prompts/SUBPROMPT_ASC_UPLOAD.md"
require_file "prompts/SUBPROMPT_CICD.md"
require_file ".codex/skills/personaos-autopilot/SKILL.md"

require_grep 'native macOS SwiftUI app' "prompts/MASTER_PROMPT.md" "Master prompt targets native macOS"
require_grep 'Release Done' "prompts/MASTER_PROMPT.md" "Master prompt defines release done"
require_grep 'name: personaos-autopilot' ".codex/skills/personaos-autopilot/SKILL.md" "Project skill has required name"
require_grep 'description: .*Mac App Store readiness' ".codex/skills/personaos-autopilot/SKILL.md" "Project skill description is triggerable"

echo
echo "== Mac App Store track =="
require_file "MAC_APP_STORE_READINESS.md"
require_grep 'PersonaOSMac.*not present yet' "MAC_APP_STORE_READINESS.md" "Mac readiness does not overclaim target existence"
require_grep 'developer\.apple\.com/help/app-store-connect/create-an-app-record/add-platforms' "MAC_APP_STORE_READINESS.md" "Mac readiness cites Apple add-platforms constraint"
require_grep 'developer\.apple\.com/documentation/appstoreconnectapi/apps' "MAC_APP_STORE_READINESS.md" "Mac readiness cites ASC API build-upload boundary"
require_grep 'developer\.apple\.com/help/app-store-connect/reference/app-sandbox-information' "MAC_APP_STORE_READINESS.md" "Mac readiness cites sandbox entitlement information"

echo
echo "== Public Pages workflow template =="
require_file "ci/deploy-pages.workflow.yml"
require_file "ci/README.md"
require_grep 'actions/upload-pages-artifact@v3' "ci/deploy-pages.workflow.yml" "GitHub Pages workflow template uploads docs artifact"
require_grep 'actions/deploy-pages@v4' "ci/deploy-pages.workflow.yml" "GitHub Pages workflow template deploys Pages"
require_grep 'path: docs' "ci/deploy-pages.workflow.yml" "GitHub Pages workflow template deploys docs folder"
require_grep 'workflow scope' "ci/README.md" "CI handoff explains workflow-scope gate"

if [[ "$failures" -eq 0 ]]; then
  echo
  echo "Release automation verification passed."
else
  echo
  echo "Release automation verification failed with $failures failure(s)." >&2
fi

exit "$failures"
