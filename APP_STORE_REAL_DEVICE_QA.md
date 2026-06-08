# App Store Real-Device QA Matrix

Use this matrix for the final PersonaOS 1.0 real-device pass before uploading or submitting a build. Do not treat simulator-only testing as enough for App Store submission.

## QA Evidence Header

Fill this section when running the final pass:

- Tester:
- Date:
- Device model:
- iOS version:
- PersonaOS version/build:
- Build source: Xcode archive / TestFlight / local run
- Network conditions tested: Wi-Fi / Cellular / Offline
- OpenAI test key used: Yes / No
- Notes contain no API keys or private data: Yes / No

## Required Device Coverage

Minimum recommended coverage before App Review:

1. One current large iPhone or simulator-equivalent UI pass for screenshot framing.
2. One physical iPhone real-device pass for Keychain, networking, export, destructive actions, and offline behavior.
3. If using TestFlight, repeat the smoke pass on the TestFlight build because signing, entitlements, and bundle provisioning differ from local debug runs.

## Core Smoke Tests

Use `REAL_AI_INTERACTION.md` for the exact Settings and Chat flow when running AI-mode checks.

| ID | Scenario | Steps | Expected result | Status |
| --- | --- | --- | --- | --- |
| RD-01 | First launch and demo data | Install fresh build, launch app, inspect Home, Tasks, Chat, Memory, Review, Settings. | App launches without crash; demo/local data appears; tab navigation works. | Not run |
| RD-02 | No-key local chat mode | Ensure no OpenAI API Key is saved; send `我该做什么` in Chat. | Assistant replies in local mode and does not require network or account setup. | Not run |
| RD-03 | Invalid-key fallback | Save an intentionally invalid OpenAI API Key; send a chat message. | App does not crash; chat bubble clearly indicates local fallback mode. | Not run |
| RD-04 | Real-key AI chat mode | Save a non-sensitive OpenAI API Key; send a non-private planning prompt. | App receives a real structured reply; suggested memories/tasks remain user-confirmed only. | Not run |
| RD-05 | Offline chat fallback | Disable network after saving a key; send `检查风险`. | App does not crash; chat falls back to local mode. | Not run |
| RD-06 | Candidate memory save | Generate or enter a candidate memory, save it, then inspect Memory. | Candidate memory appears locally and is not auto-confirmed unless user confirms it. | Not run |
| RD-07 | Suggested task save | Trigger a suggested task from Chat and tap to add it. | Task appears in today's tasks without duplicating existing open/today tasks. | Not run |
| RD-08 | Daily review | Generate or update today's review. | Review summary appears; Home recognizes the daily review state. | Not run |
| RD-09 | Local JSON export | Use Settings -> export local data. | Export succeeds; exported JSON does not contain OpenAI API Key. | Not run |
| RD-10 | Destructive data actions | Clear chat, memories, reviews, ignored memories, and reset demo data. | Actions require explicit user intent, complete without crash, and preserve unrelated data where expected. | Not run |
| RD-11 | Delete API Key | Save a test key, delete it in Settings, then send a chat message. | Key is removed; chat returns to local mode. | Not run |
| RD-12 | Settings privacy copy | Inspect Settings AI/privacy sections. | Copy says real AI sends bounded context only; no hidden permissions are implied. | Not run |
| RD-13 | Portrait-only UI | Rotate the device and inspect each tab. | App remains portrait; no clipped tab labels or overlapping text. | Not run |
| RD-14 | Public pages | Open final Support URL and Privacy Policy URL over HTTPS, then open the in-app Settings links for Support, Privacy Policy, and Accessibility. | All pages load publicly and match the submitted app behavior. | Not run |
| RD-15 | Screenshot validation | Capture the required six screenshots and run `scripts/verify_app_store_readiness.sh --with-screenshots`. | Screenshot validator passes; screenshots contain no private data or API keys. | Not run |
| RD-16 | Accessibility smoke | Run common tasks with VoiceOver enabled, Larger Text at 200%, and light/dark appearances. | Do not publish accessibility support claims unless all common tasks pass for that feature. | Not run |

## Final Archive/TestFlight Checks

| ID | Scenario | Steps | Expected result | Status |
| --- | --- | --- | --- | --- |
| TF-01 | App Store signing smoke | Install the archived/TestFlight build on a physical iPhone. | App launches and persists local data across relaunch. | Not run |
| TF-02 | Keychain on signed build | Save/delete an OpenAI API Key in the signed build. | Keychain operations work and key is not visible after save. | Not run |
| TF-03 | Export on signed build | Export local JSON from the signed build. | Export works through the system file exporter. | Not run |
| TF-04 | Review metadata alignment | Compare App Store metadata, screenshots, privacy answers, age rating, and public pages against the signed build. | No claim contradicts actual app behavior. | Not run |

## No-Go Conditions

Do not submit if any of these are true:

- A crash occurs on launch, tab navigation, chat send, export, or destructive data actions.
- Any screenshot, exported JSON, log, issue, or QA note contains a real OpenAI API Key or private user content.
- Real AI can automatically create tasks, confirm memories, delete data, or change reviews without explicit user action.
- Public Support URL or Privacy Policy URL does not load over HTTPS.
- App Store privacy answers, age rating, screenshots, or review notes do not match the signed build.
- `scripts/verify_app_store_readiness.sh --with-build --with-tests` fails.
- Captured screenshots fail `scripts/verify_app_store_readiness.sh --with-screenshots`.
- Accessibility Nutrition Label claims have not been verified against `APP_STORE_ACCESSIBILITY.md`.
