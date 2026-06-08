# PersonaOS Privacy Policy Draft

Last updated: June 8, 2026

This draft is provided for the developer account owner to review, adapt, publish, and link in App Store Connect before submitting PersonaOS to App Review. A publishable HTML version is also available at `docs/privacy.html`.

## Overview

PersonaOS is a productivity companion app for tasks, memories, daily reviews, and mentor-style chat. The app is local-first: your profile, tasks, memories, daily reviews, and chat records are stored on your device with SwiftData.

## Data You Provide

PersonaOS may store the following information when you enter it in the app:

- Profile name and companion configuration
- Tasks, quest lines, completion status, due dates, and XP values
- Memories and memory tags
- Daily review summaries and comments
- Chat messages
- An optional OpenAI API Key

## OpenAI API Key

If you choose to enable real AI chat, PersonaOS lets you paste an OpenAI API Key in Settings. The key is stored in iOS Keychain on your device. PersonaOS does not write the key to SwiftData, app logs, Git, or analytics systems.

If no API Key is configured, PersonaOS uses local deterministic replies.

## Data Sent to OpenAI

When real AI chat is enabled, PersonaOS sends only the context needed to generate a reply:

- Your current message
- Profile and companion display names
- Current main quest and task summaries
- Recent confirmed memories
- Recent daily review summaries

PersonaOS does not read other apps, access Contacts, record audio, access location, access Health data, access Calendar data, collect data in the background, or send full local chat history by default.

OpenAI processes the information according to its own terms and privacy policy. You should review OpenAI's policies before enabling real AI chat.

## Tracking and Advertising

PersonaOS does not track you across apps or websites. PersonaOS does not use your data for third-party advertising.

## Data Deletion

You can clear chat, memories, daily reports, and demo data from the in-app Settings screen. You can delete the stored OpenAI API Key from Settings.

## Contact

For support, bug reports, and privacy questions, use the PersonaOS support page published from `docs/support.html`.
