# App Store Metadata Draft

Use this draft as a starting point for App Store Connect. Final wording, screenshots, support URL, and privacy policy URL must be reviewed by the developer account owner before submission.

## App Information

- Name: PersonaOS
- Subtitle: Personal mentor for daily focus
- Bundle ID: `com.woshiluozhi.personaos`
- Category: Productivity
- Expected Age Rating: 4+
- Candidate Support URL: `https://woshiluozhi.github.io/PersonaOS/support.html` after GitHub Pages is enabled
- Candidate Privacy Policy URL: `https://woshiluozhi.github.io/PersonaOS/privacy.html` after GitHub Pages is enabled
- Content Rights: PersonaOS uses original app UI and generated first-party icon artwork.

## Promotional Text

Turn scattered tasks, memories, and daily reflections into a focused personal operating system with a mentor-style companion.

## Description

PersonaOS is a local-first productivity companion for people who want a stricter, calmer way to manage daily focus.

Create quest lines, track daily tasks, save important memories, and generate daily reviews. The companion chat helps turn vague thoughts into concrete next actions, risk checks, and candidate memories you can confirm before saving.

PersonaOS works without an API key in local deterministic mode. If you choose to enable real AI chat, you can save your own OpenAI API Key in Settings. The key is stored in iOS Keychain, and the app sends only essential context needed for replies.

Key features:

- Main, side, and daily quest tracking
- Today action recommendations
- Mentor-style chat with local fallback
- Candidate memories that require confirmation
- Daily reviews and progress summaries
- Local-first storage with JSON export and explicit delete controls

PersonaOS does not read other apps, record audio, access location, access Health data, or access Calendar data.

## Keywords

productivity, focus, tasks, journal, memory, ai, mentor, review, planning

## Review Notes

PersonaOS can be tested without an OpenAI API Key. In that mode, the chat screen uses deterministic local replies. If reviewers choose to test real AI mode, they can enter an OpenAI API Key in Settings. The app stores the key in iOS Keychain and sends only the current user message plus bounded essential context for structured chat replies.

The assistant can suggest memories and tasks, but users must explicitly tap to save those suggestions. No hidden monitoring, background recording, location access, Health access, Calendar access, or cross-app tracking is implemented.

The Settings screen lets reviewers export local SwiftData content as JSON and delete local chat, memory, and daily review data. The export does not include the OpenAI API Key stored in Keychain.

## Screenshot Checklist

- Use `APP_STORE_SCREENSHOTS.md` as the source checklist.
- Use portrait iPhone screenshots.
- Home dashboard with Today Action visible
- Quest/task list with main and daily tasks
- Chat screen showing local mode or real AI mode response
- Memory screen with confirmed/candidate memories
- Daily review screen with trend/summary
- Settings screen showing AI Mode and privacy copy
