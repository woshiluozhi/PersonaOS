# App Store Privacy Answers Draft

Use this draft when filling out App Store Connect privacy and export compliance questions for PersonaOS. The account owner must review the final answers against the released build, OpenAI account terms, and any published privacy policy.

## Sources

- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple Export Compliance Overview: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
- Apple Export Compliance Documentation Reference: https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption

## App Privacy Summary

PersonaOS is local-first by default. Local SwiftData records stay on device unless the user explicitly exports local JSON or enables real AI chat with their own OpenAI API Key.

PersonaOS does not include advertising SDKs, analytics SDKs, data broker integrations, social login SDKs, third-party tracking SDKs, Contacts access, Calendar access, Health access, location access, microphone access, camera access, or background collection.

## Data Types to Disclose

### Name

- Data type: Contact Info -> Name
- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Product Personalization
- Rationale: The user can enter a profile display name, and real AI mode may send that display name as part of bounded context for personalized chat replies.

### Other User Content

- Data type: User Content -> Other User Content
- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Product Personalization
- Rationale: User-created tasks, quest lines, memories, daily reviews, and chat messages are free-form content. In real AI mode, PersonaOS sends the current user message plus bounded essential context to OpenAI to service the chat request.

## Data Types Not Used

Answer No / Not Collected for:

- Email Address
- Phone Number
- Physical Address
- Other User Contact Info
- Health
- Fitness
- Payment Info
- Credit Info
- Other Financial Info
- Precise Location
- Coarse Location
- Sensitive Info
- Contacts
- Emails or Text Messages
- Photos or Videos
- Audio Data
- Gameplay Content
- Customer Support Data
- Browsing History
- Search History
- User ID
- Device ID
- Purchase History
- Product Interaction
- Advertising Data
- Other Usage Data
- Crash Data
- Performance Data
- Other Diagnostic Data
- Environment Scanning
- Hands
- Head
- Other Data Types

## OpenAI API Key Handling

The user may paste an OpenAI API Key in Settings.

- Stored only in iOS Keychain.
- Not written to SwiftData.
- Not included in local JSON export.
- Not committed to Git.
- Not logged by app code.
- Sent only as an HTTPS authorization credential to OpenAI when real AI chat is used.

Because Apple defines collection around data transmitted off device and retained longer than necessary to service the request, the account owner should confirm whether the OpenAI API Key itself needs separate disclosure under the final OpenAI processing terms. The current app metadata and privacy policy draft disclose API Key storage and OpenAI transmission behavior explicitly.

## Tracking

- Does PersonaOS track users across apps or websites? No.
- Does PersonaOS share data with data brokers? No.
- Does PersonaOS use data for third-party advertising? No.
- Does PersonaOS use data for developer advertising or marketing? No.

## Third-Party Data Processing

OpenAI is used only when the user saves an OpenAI API Key and sends a chat message. PersonaOS sends:

- Current user message
- Profile and companion display names
- Current main quest/task state
- Today tasks
- Overdue tasks
- Up to 5 confirmed memories
- Up to 3 recent daily review summaries

PersonaOS does not send full chat history, contacts, calendar data, health data, location, audio, photos, or background data.

## Export Compliance

PersonaOS uses Apple operating-system encryption through:

- HTTPS networking via `URLSession` for OpenAI Responses API calls.
- iOS Keychain for local API Key storage.

PersonaOS does not implement proprietary or non-standard encryption algorithms. The app target sets `ITSAppUsesNonExemptEncryption` to `NO` through generated Info.plist build settings.

Suggested App Store Connect answer:

- Uses encryption: Yes, only encryption provided by Apple's operating system / HTTPS / Keychain.
- Uses non-exempt encryption: No.
- Documentation upload: No documentation expected for encryption limited to Apple operating-system functionality.

The account owner remains responsible for confirming export compliance for target countries and the final submitted build.
