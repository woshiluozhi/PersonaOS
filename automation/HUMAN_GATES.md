# PersonaOS Human Gates

These items are allowed to require owner action or final approval. They should not block unrelated engineering tasks.

## Open Gates

| Gate | Owner action needed | Blocks |
| --- | --- | --- |
| Brand/IP rights | Confirm whether `PersonaOS` and the in-app companion name are final and commercially cleared. Default release-safe companion name is `Guide`. | Final metadata, screenshots, review notes |
| Seller, tax, banking | Complete Apple Developer Program seller, tax, banking, and agreements. | Paid app sale, final submission |
| EU trader status | Confirm App Store Connect trader status and any required public contact fields. | Final submission |
| Final price | Choose paid-upfront price tier and sale territories. | Paid app configuration |
| Final age rating answers | Answer live App Store Connect age rating questionnaire based on the final build. | App Review submission |
| Final privacy policy wording | Review public privacy policy and OpenAI processing wording before publishing. | Privacy URL, App Privacy answers |
| External purchase policy | Confirm no external purchase links or special commerce terms are needed for 1.0. | Metadata and review notes |
| Signing and ASC credentials | Provide Apple distribution signing and optional App Store Connect API/Transporter credentials on the local machine or CI. | Archive upload, metadata sync |
| GitHub workflow scope | Install `ci/deploy-pages.workflow.yml` as `.github/workflows/deploy-pages.yml` with a GitHub credential that has `workflow` scope, then enable Pages with Source set to GitHub Actions. | Public support/privacy/accessibility page deployment |

## Rule

If a task hits one of these gates, record it here and continue on non-blocked work. Do not ask the owner for ordinary implementation, test, or documentation choices.
