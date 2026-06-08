#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

screenshots_dir="${1:-BuildLogs/AppStoreScreenshots}"

required_screenshots=(
  "01-home.png"
  "02-tasks.png"
  "03-chat-local.png"
  "04-memory.png"
  "05-review.png"
  "06-settings-ai-privacy.png"
)

accepted_portrait_sizes=(
  "1260x2736"
  "1290x2796"
  "1320x2868"
  "1284x2778"
  "1242x2688"
  "1179x2556"
  "1206x2622"
  "1170x2532"
  "1125x2436"
  "1080x2340"
  "1242x2208"
  "750x1334"
  "640x1136"
  "640x1096"
  "640x960"
  "640x920"
)

failures=0
expected_size=""

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

is_accepted_size() {
  local size="$1"

  for accepted_size in "${accepted_portrait_sizes[@]}"; do
    if [[ "$size" == "$accepted_size" ]]; then
      return 0
    fi
  done

  return 1
}

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required but was not found." >&2
  exit 1
fi

echo "== App Store screenshot set =="
echo "Directory: $screenshots_dir"

if [[ ! -d "$screenshots_dir" ]]; then
  echo "Screenshot directory does not exist: $screenshots_dir" >&2
  exit 1
fi

for screenshot_name in "${required_screenshots[@]}"; do
  screenshot_path="$screenshots_dir/$screenshot_name"

  if [[ ! -f "$screenshot_path" ]]; then
    fail "$screenshot_name is missing"
    continue
  fi

  width="$(sips -g pixelWidth "$screenshot_path" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$screenshot_path" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
  alpha="$(sips -g hasAlpha "$screenshot_path" 2>/dev/null | awk '/hasAlpha/ {print $2}')"
  size="${width}x${height}"

  [[ "$alpha" == "no" ]] && pass "$screenshot_name has no alpha channel" || fail "$screenshot_name has an alpha channel"

  if is_accepted_size "$size"; then
    pass "$screenshot_name uses accepted iPhone portrait size $width x $height"
  else
    fail "$screenshot_name size $width x $height is not in the checked iPhone portrait size list"
  fi

  if [[ -z "$expected_size" ]]; then
    expected_size="$size"
  elif [[ "$size" == "$expected_size" ]]; then
    pass "$screenshot_name matches the first screenshot size"
  else
    fail "$screenshot_name size $size does not match first screenshot size $expected_size"
  fi
done

echo
if [[ "$failures" -eq 0 ]]; then
  echo "App Store screenshot validation passed."
  exit 0
fi

echo "App Store screenshot validation failed with $failures issue(s)." >&2
exit 1
