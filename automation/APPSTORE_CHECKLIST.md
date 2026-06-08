# PersonaOS App Store Checklist

## Current iOS Track

- [x] iOS SwiftUI MVP builds.
- [x] Local deterministic chat mode works without API Key.
- [x] Optional OpenAI mode uses Keychain and bounded context.
- [x] Privacy manifest exists and declares no tracking.
- [x] iPhone App Store docs and screenshot plan exist.
- [x] GitHub Pages workflow template exists for `docs/`.
- [ ] Active GitHub Pages workflow is installed under `.github/workflows/`.
- [ ] Public support/privacy/accessibility URLs are live.
- [ ] Real-device QA matrix has been completed on the signed build.
- [ ] Final screenshots have been captured and validated.
- [ ] Apple Developer signing and App Store Connect app record are configured.

## Native macOS Track

- [ ] Shared-core extraction plan exists.
- [ ] `PersonaOSMac` target and scheme exist.
- [ ] macOS Debug build passes.
- [ ] macOS Release build passes.
- [ ] macOS App Sandbox entitlements are allowlisted.
- [ ] macOS unit/integration tests pass.
- [ ] macOS UI smoke coverage exists.
- [ ] macOS screenshots and metadata exist.
- [ ] macOS archive/export scripts exist.
- [ ] Binary upload or owner handoff bundle exists.

## Non-Regression Requirements

- [ ] Local mode must always work without OpenAI.
- [ ] AI may suggest tasks/memories but must not write them automatically.
- [ ] Exports must not contain Keychain API keys.
- [ ] Source, docs, logs, screenshots, and artifacts must not contain real API keys.
- [ ] No third-party SDK, ads, tracking, analytics, background collection, or protected permissions unless explicitly accepted in `automation/DECISIONS.yaml`.
