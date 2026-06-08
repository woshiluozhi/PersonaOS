# Public Support And Privacy Pages

This document tracks the public web pages needed by App Store Connect for PersonaOS 1.0. The static files are in `docs/` so the repository owner can publish them with GitHub Pages or another static host.

## Candidate URLs

If GitHub Pages is enabled for the `main` branch and `/docs` folder, use:

- Support URL: `https://woshiluozhi.github.io/PersonaOS/support.html`
- Privacy Policy URL: `https://woshiluozhi.github.io/PersonaOS/privacy.html`

If another host is used, keep the page content equivalent and update App Store Connect with the final public URLs.

## Files

- `docs/index.html`
- `docs/support.html`
- `docs/privacy.html`

## Support Page Requirements

Apple's platform version information says the Support URL is required and should lead to contact information so users can reach the developer about app issues, feedback, and feature requests. The current support page provides the public GitHub issue tracker as the support contact path.

Before submission, the account owner should decide whether local law or App Review expectations require adding a private support email, telephone number, or legal address. If so, update `docs/support.html` before publishing.

## Privacy Page Requirements

Apple requires a Privacy Policy URL for iOS apps. The current privacy page covers:

- Local-first SwiftData storage.
- Optional OpenAI API Key storage in iOS Keychain.
- Data sent to OpenAI only when real AI chat is enabled.
- No tracking or third-party advertising.
- In-app deletion controls.
- Support contact path.

## GitHub Pages Setup

The repository owner can publish the pages by enabling GitHub Pages in repository settings:

1. Open the GitHub repository settings.
2. Go to Pages.
3. Set Source to deploy from a branch.
4. Select branch `main` and folder `/docs`.
5. Save and wait for GitHub Pages to publish.
6. Open both candidate URLs and confirm they load over HTTPS.
7. Enter the final URLs in App Store Connect.

## No-Go Conditions

Do not submit the app if:

- Either final URL does not load publicly over HTTPS.
- The support page lacks a usable support contact path.
- The privacy page does not match the submitted app's actual data behavior.
- The support or privacy page contains real API keys, private task data, private memories, or placeholder contact instructions.
