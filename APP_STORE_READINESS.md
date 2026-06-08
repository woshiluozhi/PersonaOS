# App Store Readiness

This document tracks PersonaOS readiness for App Store distribution. It separates engineering work that can be completed in this repo from account, legal, and App Store Connect work that must be completed by the developer account owner.

## Engineering Status

- App icon: present in `PersonaOS/Resources/Assets.xcassets/AppIcon.appiconset` as a 1024 x 1024 RGB PNG with no alpha.
- Asset catalog: present and wired into the app target.
- Privacy manifest: present at `PersonaOS/Resources/PrivacyInfo.xcprivacy` and wired into the app target resources.
- Privacy manifest declarations: no tracking; name and user-generated content are declared for app functionality and product personalization.
- Export compliance: generated Info.plist declares `ITSAppUsesNonExemptEncryption = NO`; PersonaOS uses only Apple operating-system encryption through HTTPS/URLSession and Keychain.
- AI mode: OpenAI API Key is saved only in iOS Keychain; chat sends bounded essential context through the Responses API, parses structured JSON output, and falls back to local mode.
- Production-style bundle identifier: app target uses `com.woshiluozhi.personaos`; test target uses `com.woshiluozhi.personaos.tests`.
- Draft App Store metadata: present in `APP_STORE_METADATA.md`.
- Draft privacy policy: present in `PRIVACY_POLICY_DRAFT.md`.
- Draft App Store privacy answers: present in `APP_STORE_PRIVACY_ANSWERS.md`.
- Draft age rating answers: present in `APP_STORE_AGE_RATING.md`; suggested direction is 4+, not Made for Kids, no higher-rating override, with owner review required.
- Draft screenshot plan: present in `APP_STORE_SCREENSHOTS.md`; helper script `scripts/capture_app_store_screenshot.sh` captures booted simulator screenshots and checks iPhone portrait dimensions.
- Draft submission package: present in `APP_STORE_SUBMISSION_PACKAGE.md`; it maps repo evidence to App Store Connect values, screenshot files, QA, and submission steps.
- Release metadata: app display name is `PersonaOS`, marketing version is `1.0`, build number is `1`, category is Productivity, deployment target is iOS 17.0, and generated launch screen is enabled.
- iPhone orientation: restricted to portrait to match the verified UI.
- In-app review/privacy cues: Settings shows version, bundle identifier, portrait-only status, AI mode boundary, and support/privacy policy reminder.
- Local data controls: Settings can export local SwiftData content as JSON and can clear chat, memories, reports, ignored memories, or reset demo data. The export excludes the OpenAI API Key stored in Keychain.
- Automated readiness gate: `scripts/verify_app_store_readiness.sh` checks required docs, submission package, screenshot plan/helper, App Icon size/alpha, privacy manifest, bundle identifiers, release metadata, iPhone portrait configuration, export compliance Info.plist key, absence of protected permissions/background modes/extra entitlements, staged local signing IDs, and likely real OpenAI API keys. With `--with-build`, it also validates built Debug/Release Info.plist metadata.
- Build verification: latest App Store readiness work passes 159 unit tests, `xcodebuild -scheme PersonaOS -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData build-for-testing`, and Release generic iOS build with `CODE_SIGNING_ALLOWED=NO`.

## Remaining Before Submission

- Apple Developer Program: enroll/use a paid Apple Developer Program account for App Store distribution.
- Bundle identifier: confirm `com.woshiluozhi.personaos` is registered and owned in the Apple Developer account.
- Signing: configure the App Store distribution team/profile in Xcode or CI.
- App Store Connect: create the app record, upload screenshots, description, keywords, support URL, and category metadata.
- Submission package: follow `APP_STORE_SUBMISSION_PACKAGE.md` while creating the app record, entering metadata, running QA, and submitting for review.
- Privacy policy: publish the draft privacy policy in `PRIVACY_POLICY_DRAFT.md`, then enter its URL in App Store Connect.
- App privacy answers: review `APP_STORE_PRIVACY_ANSWERS.md`, then disclose user-provided name/content and OpenAI processing accurately in App Store Connect.
- Age rating: review `APP_STORE_AGE_RATING.md`, answer the live App Store Connect questionnaire, and confirm the calculated rating before submission.
- Export compliance: confirm `ITSAppUsesNonExemptEncryption = NO` remains accurate for the final build and answer App Store Connect encryption/export questions for HTTPS/TLS and Keychain usage.
- Production QA: test the archive on real devices, including no-key local mode, invalid-key fallback, real-key AI mode, offline behavior, and destructive data actions.
- Screenshots: capture portrait iPhone screenshots for Dashboard, Tasks, Chat, Memory, Daily Review, and Settings using `APP_STORE_SCREENSHOTS.md`.
- Final engineering gate: run `scripts/verify_app_store_readiness.sh --with-build` immediately before archive/upload.

## Recommended Product Metadata Draft

- Name: PersonaOS
- Subtitle: Personal mentor for daily focus
- Category: Productivity
- Expected age rating: 4+
- Support URL: to be provided by the account owner
- Privacy Policy URL: to be provided by the account owner

## Review Notes Draft

PersonaOS is a local-first productivity companion. Users can manage tasks, memories, daily reviews, and chat with a mentor-style assistant. Without an OpenAI API Key, the assistant runs in local deterministic mode. If users choose to save an OpenAI API Key in Settings, the app stores it in iOS Keychain and sends only essential context needed for chat replies. The assistant can suggest memories and tasks, but users must explicitly confirm before anything is written to local data.
