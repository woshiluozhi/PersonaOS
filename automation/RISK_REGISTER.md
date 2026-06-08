# PersonaOS Risk Register

| ID | Risk | Status | Mitigation |
| --- | --- | --- | --- |
| R-001 | Existing store assets and readiness docs are iPhone-first while the long-term release target is macOS native. | Open | Keep iOS docs intact and add macOS-specific readiness, screenshots, metadata, and gates. |
| R-002 | Native macOS App Store builds require App Sandbox entitlements; the current iOS readiness gate expects no entitlements. | Open | Add macOS-only entitlement allowlist and avoid temporary exceptions unless explicitly justified. |
| R-003 | App Store Connect API cannot directly upload app binaries. | Open | Separate metadata automation from binary upload; use Xcode or Transporter, or generate owner handoff bundle. |
| R-004 | Public support/privacy/accessibility URLs may be 404 until GitHub Pages is enabled and deployed. | Owner gate | Commit workflow template, require owner to install active workflow with `workflow` scope, and keep `--with-public-pages` as the final public URL gate. |
| R-005 | Final age rating can change under the live App Store Connect questionnaire, especially for AI assistant behavior. | Owner gate | Keep local mode bounded, disclose optional AI, and require account-owner confirmation before submission. |
| R-006 | Companion naming and app copy could create perceived IP or trademark risk. | Owner gate | Default release companion name to `Guide`; replace risky names unless owner provides rights evidence. |
| R-007 | Signing certificates, profiles, App Store Connect API keys, seller/tax/banking data, and price are owner-controlled. | Owner gate | Never write credentials to Git; generate scripts and handoff docs when credentials are missing. |
