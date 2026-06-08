# App Store Submission Package

This package turns the repo-ready work into the concrete App Store Connect checklist for PersonaOS 1.0. It is meant for the Apple Developer account owner who will create the app record, configure signing, upload the build, and submit for review.

## Official References

- App information reference: https://developer.apple.com/help/app-store-connect/reference/app-information/
- App privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Upload app previews and screenshots: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots
- Submit an app: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/

## Repo Evidence

| Area | Repo evidence | Status |
| --- | --- | --- |
| Bundle ID | `com.woshiluozhi.personaos` in `PersonaOS.xcodeproj/project.pbxproj` | Ready, account owner must register it |
| Version | Marketing version `1.0`, build `1` | Ready |
| Category | Productivity | Ready |
| App icon | `PersonaOS-AppIcon-1024.png`, 1024 x 1024, no alpha | Ready |
| Privacy manifest | `PersonaOS/Resources/PrivacyInfo.xcprivacy` | Ready |
| Metadata draft | `APP_STORE_METADATA.md` | Drafted |
| Privacy policy draft | `PRIVACY_POLICY_DRAFT.md` | Drafted, needs public URL |
| Public support/privacy pages | `docs/support.html`, `docs/privacy.html`, `APP_STORE_PUBLIC_PAGES.md` | Drafted, needs GitHub Pages or static hosting |
| Public page deployment | `ci/deploy-pages.workflow.yml`, `ci/README.md` | Template ready, owner must install active workflow with a credential that has `workflow` scope |
| In-app public links | `PersonaOS/Features/Settings/SettingsView.swift` | Wired to candidate Support, Privacy Policy, and Accessibility URLs |
| Real AI interaction handoff | `REAL_AI_INTERACTION.md` | Documented, needs real-key and offline smoke on final build |
| Accessibility labels | `APP_STORE_ACCESSIBILITY.md`, `docs/accessibility.html` | Drafted, needs real-device audit before claims |
| Privacy answers | `APP_STORE_PRIVACY_ANSWERS.md` | Drafted, needs account-owner review |
| Age rating | `APP_STORE_AGE_RATING.md` | Drafted, needs live questionnaire confirmation |
| Screenshots | `APP_STORE_SCREENSHOTS.md`, `scripts/capture_app_store_screenshot.sh`, `scripts/validate_app_store_screenshots.sh` | Plan ready, final images still need capture |
| Real-device QA | `APP_STORE_REAL_DEVICE_QA.md` | Matrix ready, final pass still needs execution |
| Engineering gate | `scripts/verify_app_store_readiness.sh --with-build --with-tests` | Run before archive |
| Release automation gate | `scripts/verify_release_automation.sh`, `automation/`, `prompts/`, `.codex/skills/personaos-autopilot/SKILL.md` | Ready for long-running Codex handoff |
| Native Mac App Store track | `MAC_APP_STORE_READINESS.md` | Planned, not ready until `PersonaOSMac` exists and passes macOS gates |

## App Store Connect Values

| Field | Value |
| --- | --- |
| Name | PersonaOS |
| Subtitle | Personal mentor for daily focus |
| Category | Productivity |
| Bundle ID | `com.woshiluozhi.personaos` |
| SKU | `personaos-ios-1` or another account-owner controlled identifier |
| Primary language | English unless the owner prefers Chinese metadata |
| Content rights | Uses original app UI and first-party app icon artwork |
| Expected age rating | 4+; not Made for Kids; no higher-rating override |
| Candidate Support URL | `https://woshiluozhi.github.io/PersonaOS/support.html` after GitHub Pages is enabled |
| Candidate Privacy Policy URL | `https://woshiluozhi.github.io/PersonaOS/privacy.html` after GitHub Pages is enabled |
| Candidate Accessibility URL | `https://woshiluozhi.github.io/PersonaOS/accessibility.html` after GitHub Pages is enabled |

## Screenshot Set

Capture a clean iPhone portrait set before submission. Use `APP_STORE_SCREENSHOTS.md` as the source plan.

Expected first set:

1. `01-home.png`
2. `02-tasks.png`
3. `03-chat-local.png`
4. `04-memory.png`
5. `05-review.png`
6. `06-settings-ai-privacy.png`

Preferred output location while preparing locally:

```sh
BuildLogs/AppStoreScreenshots/
```

Do not include real API keys, real personal memories, private notes, debug overlays, or simulator chrome.

## Privacy And Review Notes

Use `APP_STORE_PRIVACY_ANSWERS.md` for privacy questionnaire answers. The account owner should review the final build and confirm:

- PersonaOS does not track users.
- PersonaOS does not include ad, analytics, social-login, location, Health, Calendar, camera, microphone, Contacts, push, or background collection permissions.
- User-provided name and user-generated content are disclosed.
- OpenAI is used only when the user saves an OpenAI API Key and sends a chat message.
- API keys are stored in Keychain, excluded from SwiftData export, and not logged.

Use the Review Notes text from `APP_STORE_METADATA.md`. Include that reviewers can test without an OpenAI API Key because local deterministic chat mode is available.

## Pre-Submission QA

Run these before creating the final archive:

```sh
scripts/verify_app_store_readiness.sh --with-build --with-tests
```

After capturing screenshots, run:

```sh
scripts/verify_app_store_readiness.sh --with-screenshots
```

After enabling GitHub Pages or the final public host, run:

```sh
scripts/verify_app_store_readiness.sh --with-public-pages
```

Then manually test on a real iPhone:

- Run the complete matrix in `APP_STORE_REAL_DEVICE_QA.md`.
- Keep QA notes free of real OpenAI API Keys and private user content.

## Submission Steps

1. Enroll or use a paid Apple Developer Program account.
2. Register `com.woshiluozhi.personaos` in Certificates, Identifiers and Profiles.
3. Configure App Store distribution signing in Xcode or CI.
4. Create the App Store Connect app record.
5. Enter metadata from `APP_STORE_METADATA.md`.
6. Publish `docs/support.html`, `docs/privacy.html`, and `docs/accessibility.html` with the GitHub Pages Actions workflow or another HTTPS host.
7. Run `scripts/verify_app_store_readiness.sh --with-public-pages`.
8. Enter the final Support URL and Privacy Policy URL.
9. Enter App Privacy answers from `APP_STORE_PRIVACY_ANSWERS.md`.
10. Answer the Age Ratings questionnaire using `APP_STORE_AGE_RATING.md` and confirm the calculated rating.
11. Review `REAL_AI_INTERACTION.md` and verify no-key, invalid-key, real-key, and offline fallback chat on the final build.
12. Review `APP_STORE_ACCESSIBILITY.md`; publish only Accessibility Nutrition Label claims verified on the final build.
13. Capture and upload screenshots from the screenshot set above.
14. Archive and upload the signed build.
15. Select the uploaded build for PersonaOS 1.0.
16. Add the app version for review, then submit for review.

## No-Go Conditions

Do not submit if any of these are true:

- The readiness gate fails.
- A real API Key appears in source, logs, screenshots, or exported JSON.
- Distribution signing is not configured.
- Privacy Policy URL or Support URL is missing.
- In-app public links do not load over HTTPS.
- `scripts/verify_app_store_readiness.sh --with-public-pages` fails after the final public host is configured.
- Age rating has not been confirmed in App Store Connect.
- Required screenshots have not passed `scripts/validate_app_store_screenshots.sh`.
- Screenshots contain private data or clipped/overlapping UI.
- Real-device QA has not covered the matrix in `APP_STORE_REAL_DEVICE_QA.md`.
- Accessibility Nutrition Label claims have not been verified on the final signed build.
