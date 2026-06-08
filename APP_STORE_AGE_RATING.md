# App Store Age Rating Draft

Use this draft when answering the App Store Connect Age Ratings questionnaire for PersonaOS 1.0. The Apple Developer account owner must review the final build and answer the live questionnaire accurately before submission.

## Official References

- Set an app age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
- Age rating values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App information reference: https://developer.apple.com/help/app-store-connect/reference/app-information/

Apple describes Age Rating as a required App Information property. App Store Connect calculates the rating from questionnaire answers about content descriptors, in-app controls, and app capabilities.

## Suggested Rating Direction

- Expected Apple global rating: `4+`
- Made for Kids: `No`
- Override to Higher Age Rating: `Not Applicable`
- Age Suitability URL: optional; leave blank unless a public support/privacy site adds a dedicated age-suitability page.

Rationale: PersonaOS is a productivity app for local tasks, memories, daily reviews, and mentor-style chat. The submitted build should not include objectionable material, unrestricted web browsing, gambling, loot boxes, advertising, user-to-user messaging, sexual content, violence, medical treatment content, or alcohol/tobacco/drug references as intended product content.

## In-App Controls

| Questionnaire area | Suggested answer | Rationale |
| --- | --- | --- |
| Parental Controls | No | PersonaOS does not provide parent/guardian restriction tooling. |
| Age Assurance | No | PersonaOS does not verify or estimate user age. |

## Capabilities

| Questionnaire area | Suggested answer | Rationale |
| --- | --- | --- |
| Unrestricted Web Access | No | PersonaOS has no embedded browser and does not let users navigate arbitrary webpages. |
| User-Generated Content | No | Users create local tasks, memories, reviews, and chat text, but the app does not broadly distribute user-created content as a public/social feature. |
| Messaging and Chat | No | The chat is user-to-AI/local assistant interaction, not user-to-user direct messaging or group/public chat. |
| Advertising | No | PersonaOS does not include ads. |

## Content Descriptors

Answer `None` for each descriptor unless the final submitted build changes materially:

- Profanity or crude humor
- Horror or fear themes
- Alcohol, tobacco, or drug use or references
- Medical or treatment information
- Health or wellness topics
- Mature or suggestive themes
- Sexual content or nudity
- Cartoon or fantasy violence
- Realistic violence
- Guns or other weapons
- Simulated gambling
- Contests
- Gambling
- Loot boxes

## AI Chat Review Note

PersonaOS can optionally call OpenAI only when the user saves an OpenAI API Key and sends a chat message. The app's intended assistant behavior is productivity planning, risk checks, and candidate memory/task suggestions. It does not provide unrestricted web access, user-to-user communication, public posting, medical advice, gambling, or mature entertainment content.

If App Store Connect exposes an AI-specific or generated-content question in the live questionnaire, answer conservatively based on the final submitted behavior and include a review note that real AI mode is optional, user-initiated, and bounded to productivity context.

## Owner Review Checklist

- Confirm no new feature adds web browsing, public posting, user-to-user chat, ads, games, medical/treatment advice, or mature content.
- Confirm screenshots and metadata do not imply therapy, healthcare treatment, financial advice, or gambling.
- Confirm OpenAI behavior is disclosed in Review Notes and privacy materials.
- Confirm the calculated age rating in App Store Connect matches expectations before submitting.
- Revisit this document for every release that changes chat behavior, content domains, permissions, or monetization.
