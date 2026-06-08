#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 1 ]]; then
  cat <<'USAGE'
Usage: scripts/capture_app_store_screenshot.sh <name>

Example:
  scripts/capture_app_store_screenshot.sh 01-home

Before running:
  1. Boot an iPhone simulator.
  2. Launch PersonaOS.
  3. Navigate to the screen you want to capture.

Output:
  BuildLogs/AppStoreScreenshots/<name>.png
USAGE
  exit 2
fi

name="$1"
if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Screenshot name may only contain letters, numbers, dot, underscore, and dash." >&2
  exit 2
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required but was not found." >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required but was not found." >&2
  exit 1
fi

output_dir="BuildLogs/AppStoreScreenshots"
mkdir -p "$output_dir"

output_path="$output_dir/$name.png"
xcrun simctl io booted screenshot "$output_path" >/dev/null

width="$(sips -g pixelWidth "$output_path" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
height="$(sips -g pixelHeight "$output_path" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
alpha="$(sips -g hasAlpha "$output_path" 2>/dev/null | awk '/hasAlpha/ {print $2}')"
size="${width}x${height}"

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

is_accepted=0
for accepted_size in "${accepted_portrait_sizes[@]}"; do
  if [[ "$size" == "$accepted_size" ]]; then
    is_accepted=1
    break
  fi
done

echo "Captured $output_path"
echo "Dimensions: $width x $height"
echo "Alpha: $alpha"

if [[ "$is_accepted" == "1" ]]; then
  echo "PASS: Dimensions match an Apple-listed iPhone portrait screenshot size."
else
  echo "WARN: Dimensions do not match the checked iPhone portrait screenshot size list." >&2
  echo "Use APP_STORE_SCREENSHOTS.md and Apple's current screenshot specifications before uploading." >&2
fi
