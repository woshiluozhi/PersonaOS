# Public Support And Privacy Pages

This document tracks the public web pages needed by App Store Connect for PersonaOS 1.0. The static files are in `docs/` so the repository owner can publish them with GitHub Pages or another static host.

## Candidate URLs

If GitHub Pages is enabled for this repository, use:

- Support URL: `https://woshiluozhi.github.io/PersonaOS/support.html`
- Privacy Policy URL: `https://woshiluozhi.github.io/PersonaOS/privacy.html`
- Accessibility URL: `https://woshiluozhi.github.io/PersonaOS/accessibility.html`

If another host is used, keep the page content equivalent and update App Store Connect with the final public URLs.

## Files

- `docs/index.html`
- `docs/support.html`
- `docs/privacy.html`
- `docs/accessibility.html`

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

## Accessibility Page Requirements

Accessibility Nutrition Labels are voluntary at the time of this draft, but App Store Connect can display an optional accessibility URL. The current page explains the features PersonaOS is evaluating and avoids claiming unsupported accessibility labels before real-device QA.

## In-App Links

`SettingsView` includes tappable links to the candidate Support, Privacy Policy, and Accessibility URLs. Before App Store submission, enable GitHub Pages or replace these URLs with the final public host so the in-app links, App Store Connect metadata, and public pages all match.

## GitHub Pages Setup

The repository now includes `ci/deploy-pages.workflow.yml`, a GitHub Pages Actions template that packages the `docs/` folder. The active `.github/workflows/deploy-pages.yml` file still needs to be installed by the repository owner using a GitHub credential with `workflow` scope. The Actions path is preferred because it is explicit and repeatable:

1. Open the GitHub repository settings.
2. Go to Pages.
3. Set Source to GitHub Actions.
4. Copy `ci/deploy-pages.workflow.yml` to `.github/workflows/deploy-pages.yml` using GitHub web UI, `gh`, or another Git client with `workflow` scope.
5. Push to `main` or run the `Deploy GitHub Pages` workflow manually.
6. Wait for the workflow to complete.
7. Open the candidate URLs and confirm they load over HTTPS.
8. Open the candidate Accessibility URL if completing Accessibility Nutrition Labels.
9. Run `scripts/verify_app_store_readiness.sh --with-public-pages` and confirm all public page checks pass.
10. Enter the final URLs in App Store Connect.

If branch-based Pages is used instead, set Source to deploy from branch `main` and folder `/docs`, then run the same public-page verification gate.

## Verification Command

After GitHub Pages or another static host is enabled, run:

```sh
scripts/verify_app_store_readiness.sh --with-public-pages
```

This optional gate checks that the candidate Support, Privacy Policy, and Accessibility URLs return HTML over HTTPS and contain the expected PersonaOS page titles. It is expected to fail while GitHub Pages is not enabled.

## No-Go Conditions

Do not submit the app if:

- Either final URL does not load publicly over HTTPS.
- `scripts/verify_app_store_readiness.sh --with-public-pages` fails after the final public host is configured.
- In-app Support, Privacy Policy, or Accessibility links point to a host that has not been published.
- `ci/deploy-pages.workflow.yml` is removed without replacing it with an equivalent documented public-page deployment path.
- The support page lacks a usable support contact path.
- The privacy page does not match the submitted app's actual data behavior.
- The support or privacy page contains real API keys, private task data, private memories, or placeholder contact instructions.
