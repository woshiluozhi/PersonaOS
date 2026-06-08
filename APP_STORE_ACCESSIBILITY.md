# App Store Accessibility Draft

Use this draft when preparing PersonaOS Accessibility Nutrition Labels in App Store Connect. The labels are currently voluntary, but Apple encourages developers to publish accurate accessibility support and says support details will become required over time for new apps and updates.

## Official References

- Overview of Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/
- Manage Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels

Apple's evaluation rule is important: before indicating support for an accessibility feature, users must be able to complete all common tasks of the app using that feature.

## Candidate Accessibility URL

If GitHub Pages is enabled for the `main` branch and `/docs` folder, use:

- Accessibility URL: `https://woshiluozhi.github.io/PersonaOS/accessibility.html`

This URL is optional in App Store Connect, but useful if Accessibility Nutrition Labels are completed.

## Common PersonaOS Tasks To Evaluate

Evaluate each accessibility feature against these common tasks:

1. Navigate all tabs: Home, Tasks, Chat, Memory, Daily Review, Settings.
2. Complete today's recommended action.
3. Create, edit, complete, reopen, and delete a task.
4. Create, confirm, ignore, restore, and delete a memory.
5. Send a chat message, cancel an in-progress reply, and save suggested tasks/memories.
6. Generate or update a daily review.
7. Save, test, and delete an OpenAI API Key in Settings.
8. Export local JSON data and perform destructive data controls.

## Draft Label Responses

| Feature | Draft response | Evidence / caveat |
| --- | --- | --- |
| VoiceOver | Needs real-device audit before claiming support | Several icon buttons have labels and charts expose combined labels, but the full common-task pass has not been recorded. |
| Voice Control | Needs real-device audit before claiming support | Most visible controls are standard SwiftUI controls, but command discoverability must be checked on device. |
| Larger Text | Needs real-device audit before claiming support | The app uses SwiftUI text styles, but 200% text must be checked for clipped labels, tab text, and dense cards. |
| Dark Interface | Candidate support | UI uses system colors and is designed around dark/light adaptive SwiftUI surfaces. Verify all screens before publishing. |
| Differentiate Without Color Alone | Needs audit before claiming support | Some task/memory states use text and icons; progress/status areas still need a focused pass. |
| Sufficient Contrast | Needs audit before claiming support | System colors help, but screenshots and custom accent uses should be checked in light and dark mode. |
| Reduced Motion | Not applicable / do not claim until verified | PersonaOS has no major custom motion, but no dedicated reduced-motion audit has been recorded. |
| Captions | Not applicable | PersonaOS does not include video or audio dialog content. |
| Audio Descriptions | Not applicable | PersonaOS does not include video content that needs audio descriptions. |

## Recommended First Submission Stance

For PersonaOS 1.0, do not publish Accessibility Nutrition Label support claims until `APP_STORE_REAL_DEVICE_QA.md` is expanded with an accessibility pass and the owner verifies every common task on a physical iPhone.

If App Store Connect requires a response before submission, answer conservatively:

- Indicate support only for features that passed the full common-task audit.
- Do not claim VoiceOver, Voice Control, Larger Text, Differentiate Without Color Alone, Sufficient Contrast, or Reduced Motion based only on partial code inspection.
- Captions and Audio Descriptions should remain not supported / not applicable because the app has no media content requiring them.

## Accessibility QA Addendum

Before publishing any support claim, record:

- Device model and iOS version.
- Feature being evaluated.
- Each common task result.
- Any screen where text clips, controls are unnamed, focus order is confusing, color is the only indicator, or contrast is weak.
- Whether the feature can be claimed for iPhone in App Store Connect.

## No-Go Conditions

Do not publish an Accessibility Nutrition Label claim if:

- Any common task cannot be completed with that feature.
- A control required for a common task has no understandable accessible name.
- Larger Text causes required text, buttons, tab labels, or form fields to clip or overlap.
- A state is communicated only through color.
- The claim has not been verified on the final signed/TestFlight build.
