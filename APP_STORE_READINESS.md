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
- Real AI interaction handoff: present in `REAL_AI_INTERACTION.md`; it documents the Keychain setup flow, Responses API boundary, bounded context, fallback behavior, and iPhone validation steps.
- Draft age rating answers: present in `APP_STORE_AGE_RATING.md`; suggested direction is 4+, not Made for Kids, no higher-rating override, with owner review required.
- Draft public support/privacy pages: present in `docs/support.html` and `docs/privacy.html`; publishing plan is documented in `APP_STORE_PUBLIC_PAGES.md`.
- Draft accessibility labels: present in `APP_STORE_ACCESSIBILITY.md`; candidate accessibility page is `docs/accessibility.html`, and support claims remain conservative until real-device QA verifies common tasks.
- Draft screenshot plan: present in `APP_STORE_SCREENSHOTS.md`; helper script `scripts/capture_app_store_screenshot.sh` captures booted simulator screenshots, and `scripts/validate_app_store_screenshots.sh` validates the complete required screenshot set.
- Draft submission package: present in `APP_STORE_SUBMISSION_PACKAGE.md`; it maps repo evidence to App Store Connect values, screenshot files, QA, and submission steps.
- Draft real-device QA matrix: present in `APP_STORE_REAL_DEVICE_QA.md`; it covers local mode, invalid key fallback, real AI mode, offline fallback, export, destructive actions, public pages, screenshots, and signed-build smoke checks.
- Release metadata: app display name is `PersonaOS`, marketing version is `1.0`, build number is `1`, category is Productivity, deployment target is iOS 17.0, and generated launch screen is enabled.
- iPhone orientation: restricted to portrait to match the verified UI.
- In-app review/privacy cues: Settings shows version, bundle identifier, portrait-only status, AI mode boundary, support/privacy policy reminder, and tappable Support, Privacy Policy, and Accessibility links.
- Local data controls: Settings can export local SwiftData content as JSON and can clear chat, memories, reports, ignored memories, or reset demo data. The export excludes the OpenAI API Key stored in Keychain.
- Automated readiness gate: `scripts/verify_app_store_readiness.sh` checks required docs, real AI interaction handoff, accessibility draft, real-device QA coverage, submission package, screenshot plan/helper, App Icon size/alpha, privacy manifest, bundle identifiers, release metadata, iPhone portrait configuration, export compliance Info.plist key, absence of protected permissions/background modes/extra entitlements, staged local signing IDs, and likely real OpenAI API keys. With `--with-build`, it also validates built Debug/Release Info.plist metadata. With `--with-screenshots`, it validates the captured screenshot set.
- Build verification: latest App Store readiness work passes the full simulator test suite, `xcodebuild -scheme PersonaOS -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ./DerivedData build-for-testing`, and Release generic iOS build with `CODE_SIGNING_ALLOWED=NO`.

## Remaining Before Submission

- Apple Developer Program: enroll/use a paid Apple Developer Program account for App Store distribution.
- Bundle identifier: confirm `com.woshiluozhi.personaos` is registered and owned in the Apple Developer account.
- Signing: configure the App Store distribution team/profile in Xcode or CI.
- App Store Connect: create the app record, upload screenshots, description, keywords, support URL, and category metadata.
- Submission package: follow `APP_STORE_SUBMISSION_PACKAGE.md` while creating the app record, entering metadata, running QA, and submitting for review.
- Public pages: publish `docs/support.html` and `docs/privacy.html` with GitHub Pages or another static host, then enter the final URLs in App Store Connect.
- Privacy policy: review `docs/privacy.html` and `PRIVACY_POLICY_DRAFT.md`, then enter the final public Privacy Policy URL in App Store Connect.
- App privacy answers: review `APP_STORE_PRIVACY_ANSWERS.md`, then disclose user-provided name/content and OpenAI processing accurately in App Store Connect.
- Age rating: review `APP_STORE_AGE_RATING.md`, answer the live App Store Connect questionnaire, and confirm the calculated rating before submission.
- Accessibility: review `APP_STORE_ACCESSIBILITY.md`, complete a real-device accessibility pass before publishing any Accessibility Nutrition Label support claims, and use `docs/accessibility.html` if adding an accessibility URL.
- Export compliance: confirm `ITSAppUsesNonExemptEncryption = NO` remains accurate for the final build and answer App Store Connect encryption/export questions for HTTPS/TLS and Keychain usage.
- Production QA: run `APP_STORE_REAL_DEVICE_QA.md` on a real iPhone and, if using TestFlight, repeat smoke checks on the signed/TestFlight build.
- Screenshots: capture portrait iPhone screenshots for Dashboard, Tasks, Chat, Memory, Daily Review, and Settings using `APP_STORE_SCREENSHOTS.md`, then run `scripts/verify_app_store_readiness.sh --with-screenshots`.
- Final engineering gate: run `scripts/verify_app_store_readiness.sh --with-build` immediately before archive/upload.

## Recommended Product Metadata Draft

- Name: PersonaOS
- Subtitle: Personal mentor for daily focus
- Category: Productivity
- Expected age rating: 4+
- Support URL: to be provided by the account owner
- Privacy Policy URL: to be provided by the account owner
- Candidate Support URL: `https://woshiluozhi.github.io/PersonaOS/support.html` after GitHub Pages is enabled
- Candidate Privacy Policy URL: `https://woshiluozhi.github.io/PersonaOS/privacy.html` after GitHub Pages is enabled

## Review Notes Draft

PersonaOS is a local-first productivity companion. Users can manage tasks, memories, daily reviews, and chat with a mentor-style assistant. Without an OpenAI API Key, the assistant runs in local deterministic mode. If users choose to save an OpenAI API Key in Settings, the app stores it in iOS Keychain and sends only essential context needed for chat replies. The assistant can suggest memories and tasks, but users must explicitly confirm before anything is written to local data.
