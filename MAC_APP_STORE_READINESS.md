# Mac App Store Readiness

This document tracks the new native macOS release path for PersonaOS. The existing iPhone-first App Store package remains useful, but it is not sufficient evidence for a native Mac App Store submission.

## Current Status

- `PersonaOSMac` target: not present yet.
- Existing iOS target: green and should be preserved.
- Shared Core: candidate files already exist under `PersonaOS/Core/`.
- Public pages: static HTML exists in `docs/`; GitHub Pages still needs to publish successfully before final submission.
- Real AI: optional BYO OpenAI API Key; local mode remains the required review-safe fallback.
- Monetization default: paid upfront, configured in App Store Connect by the account owner.

## Official Constraints

- Apple's Add Platforms help states that macOS platform versions must upload macOS builds from a separate Xcode target when adding platform builds to an app record: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms/
- Apple's Upload Builds help documents Xcode/Transporter upload paths and notes Transporter with JWT as the binary-upload path when using App Store Connect API credentials: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- The App Store Connect API Apps documentation states that the API does not directly upload builds and can be used with Transporter credentials instead: https://developer.apple.com/documentation/appstoreconnectapi/apps
- App information requires a Privacy Policy URL for iOS and macOS apps: https://developer.apple.com/help/app-store-connect/reference/app-information
- App Sandbox temporary exception entitlements require App Store Connect usage information, so the macOS target should use the smallest entitlement allowlist possible: https://developer.apple.com/help/app-store-connect/reference/app-sandbox-information/
- Age ratings are generated from the live App Store Connect questionnaire and vary under the OS 26-era age-rating system: https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/

## Native macOS Milestones

1. Extract and document shared Core boundaries for models, services, utilities, and AI clients.
2. Add a `PersonaOSMac` target and scheme without breaking the existing iOS `PersonaOS` scheme.
3. Add macOS UI shell for Dashboard, Tasks, Chat, Memory, Daily Review, and Settings.
4. Add macOS App Sandbox entitlements with an explicit allowlist.
5. Add macOS build, test, archive, and export scripts.
6. Add macOS screenshot plan, metadata, review notes, and privacy mapping.
7. Add upload or owner handoff flow for Xcode/Transporter.

## Verification Targets

Planned commands:

```sh
xcodebuild -project PersonaOS.xcodeproj -scheme PersonaOSMac -configuration Debug -destination 'platform=macOS' -derivedDataPath DerivedData build
```

```sh
xcodebuild -project PersonaOS.xcodeproj -scheme PersonaOSMac -configuration Release -destination 'generic/platform=macOS' -derivedDataPath DerivedData build
```

```sh
xcodebuild -project PersonaOS.xcodeproj -scheme PersonaOSMac -configuration Release -destination 'generic/platform=macOS' -archivePath Build/PersonaOSMac.xcarchive archive
```

These are future gates; they are not expected to pass until `PersonaOSMac` exists.

## Owner Gates

See `automation/HUMAN_GATES.md` for final decisions that Codex should not invent: brand/IP rights, seller/tax/banking, EU trader status, final price, final age rating, final privacy wording, external purchase policy, and signing/App Store Connect credentials.
