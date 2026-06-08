# App Store Screenshot Plan

Use this plan to capture the first App Store screenshot set for PersonaOS. The app target is iPhone-only, so the first submission should focus on iPhone portrait screenshots.

## Official References

- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple upload workflow: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots

## Required Device Family

PersonaOS currently sets `TARGETED_DEVICE_FAMILY = 1`, so App Store Connect should require iPhone screenshots only. Do not enable iPad support unless the app is explicitly designed and tested for iPad, because iPad support adds iPad screenshot requirements.

## Recommended Screenshot Size

Prefer a 6.9-inch iPhone portrait simulator/device screenshot for the primary iPhone set.

Accepted 6.9-inch portrait sizes in Apple's current screenshot specification include:

- `1260 x 2736`
- `1290 x 2796`
- `1320 x 2868`

If a 6.9-inch simulator/device is not available, Apple also lists 6.5-inch portrait sizes that can satisfy the iPhone requirement when 6.9-inch screenshots are not provided:

- `1284 x 2778`
- `1242 x 2688`

## Capture Workflow

1. Run the latest build on a large iPhone simulator, preferably `iPhone 17 Pro Max`, `iPhone 16 Pro Max`, or another 6.9-inch device.
2. Use clean demo data. Do not show a real OpenAI API Key, real private memories, real personal notes, or real account details.
3. Navigate manually to the intended screen.
4. Capture with:

```sh
scripts/capture_app_store_screenshot.sh 01-home
```

The script writes PNG files to `BuildLogs/AppStoreScreenshots/` and reports whether the captured dimensions match accepted iPhone portrait screenshot sizes.

After capturing all required shots, validate the complete set with:

```sh
scripts/validate_app_store_screenshots.sh
```

The validator checks that every required PNG exists, has no alpha channel, uses an accepted iPhone portrait size, and matches the first screenshot's dimensions.

## Required PersonaOS Shots

Capture at least these six portrait screenshots:

1. `01-home.png`
   - Home dashboard with Today Action visible.
   - Show current main quest and status panel.

2. `02-tasks.png`
   - Tasks screen with main and daily tasks visible.
   - Include due-date state or today/overdue summary if possible.

3. `03-chat-local.png`
   - Chat screen showing deterministic local mode response.
   - No API Key required; this is safest for App Review screenshots.

4. `04-memory.png`
   - Memory screen with confirmed and candidate memory states visible.
   - Avoid real personal memories.

5. `05-review.png`
   - Daily review screen with trend or summary visible.
   - Show generated review content from demo data.

6. `06-settings-ai-privacy.png`
   - Settings screen showing AI Mode and privacy copy.
   - Do not show a saved or typed API Key.

## Optional Shot

7. `07-chat-real-ai.png`
   - Only capture this if using a non-sensitive test key and the screenshot does not reveal the key.
   - Prefer not to include this in the first submission unless real AI behavior materially improves the product page.

## Screenshot Review Checklist

- Portrait only.
- No transparent PNG.
- No real API Key or real personal data.
- No clipped tab bar text.
- No overlapping text.
- No blank loading state.
- No debug UI, simulator chrome, or Xcode overlays.
- No copyrighted third-party content.
- First screenshot should make the product category obvious within the first viewport.
- The order in App Store Connect should match the user story: Home -> Tasks -> Chat -> Memory -> Review -> Settings.
- Run `scripts/validate_app_store_screenshots.sh` before upload.

## App Store Connect Notes

After upload, Apple may process previews/screenshots for a while. Once an app version is approved, screenshots usually require creating a new version to change them, so review the final order and privacy boundaries before submission.
