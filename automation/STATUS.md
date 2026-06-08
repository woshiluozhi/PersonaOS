# PersonaOS Automation Status

Last updated: 2026-06-09

## Current Phase

- Phase: `foundation`
- Active target: `macos_native`
- Existing green target: iOS SwiftUI MVP
- Release state: `not_release_done`
- Current checkpoint: `5b16045 Add public pages readiness gate`
- Local-only dirty file: `PersonaOS.xcodeproj/project.pbxproj` contains the developer Team ID for real-device signing and must not be staged.

## Current Evidence

- iOS app target builds and tests on `platform=iOS Simulator,name=iPhone 17`.
- Real AI text interaction is implemented with optional BYO OpenAI API Key, Keychain storage, bounded context, structured response parsing, and visible local fallback.
- Existing App Store docs, privacy drafts, screenshot plan, real-device QA matrix, and static readiness gate are iPhone-first.
- Public support, privacy, and accessibility pages exist in `docs/`, but their public GitHub Pages URLs still require publication before App Store submission.
- No native macOS target exists yet; `PersonaOSMac` is a planned target, not a current build product.

## Current Task

`AUTO-001` is complete. A durable automation state layer, project prompt set, project-local skill, GitHub Pages workflow template, release automation gate, and macOS App Store readiness track now exist.

## Commands Run In Latest Verified Pass

- `xcodebuild -scheme PersonaOS -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData build-for-testing`
- `xcodebuild test-without-building -scheme PersonaOS -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData`
- `scripts/verify_release_automation.sh`
- `bash -n scripts/verify_release_automation.sh && bash -n scripts/verify_app_store_readiness.sh`
- `scripts/verify_app_store_readiness.sh`

## Next Best Task

Execute `MAC-001`: create the `PersonaOSMac` target strategy and shared-core extraction plan before editing the Xcode project. Keep the iOS target green while adding macOS-specific readiness gates.

## Release Done Criteria

Do not mark `release_done` until:

- Native macOS target Debug and Release builds pass.
- Core automated tests are green.
- macOS App Sandbox entitlements are allowlisted and documented.
- macOS metadata, screenshots, privacy/public pages, accessibility notes, and review notes are complete.
- Archive/export/upload or owner handoff bundle is complete.
- `automation/HUMAN_GATES.md` has no blocker that prevents submission.
