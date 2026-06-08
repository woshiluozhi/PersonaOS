---
name: personaos-autopilot
description: Use when continuing PersonaOS toward native Mac App Store readiness, including backlog selection, automation state updates, macOS target planning, App Store docs, public pages, packaging, signing handoff, and release gating.
---

# PersonaOS Autopilot

Use this skill for durable PersonaOS release work. Keep changes small, verified, and recoverable from files on disk.

## Start

1. Read `automation/DECISIONS.yaml`, `automation/STATUS.md`, `automation/BACKLOG.yaml`, and `automation/HUMAN_GATES.md`.
2. Check `git status --short` and protect local-only signing changes.
3. Choose the smallest useful backlog item that is not owner-blocked.
4. Record the rollback point in `automation/STATUS.md` or `automation/RUN_LOG.md`.

## Defaults

- Native macOS App Store is the primary release track.
- Existing iOS target must stay green.
- Local AI mode must always work; OpenAI is optional BYO Key.
- No third-party SDKs, ads, tracking, analytics, cloud sync, or external purchase links by default.
- Use neutral release-safe names if brand/IP risk is unclear.

## Human Gates

Only stop for owner input on brand/IP rights, seller/tax/banking, EU trader status, final price, final age rating, final privacy wording, external purchase policy, and signing/App Store Connect credentials. Otherwise write the issue to `automation/HUMAN_GATES.md` and continue.

## References

- Master workflow: `prompts/MASTER_PROMPT.md`
- Task template: `prompts/TASK_INPUT_TEMPLATE.md`
- Implementation: `prompts/SUBPROMPT_IMPLEMENT.md`
- Tests: `prompts/SUBPROMPT_TEST.md`
- UI tests: `prompts/SUBPROMPT_UITEST.md`
- Package/signing: `prompts/SUBPROMPT_PACKAGE_SIGN.md`
- Metadata/privacy: `prompts/SUBPROMPT_METADATA_PRIVACY.md`
- App Store Connect upload: `prompts/SUBPROMPT_ASC_UPLOAD.md`
- CI/CD: `prompts/SUBPROMPT_CICD.md`

## Finish

Run the narrowest relevant verification plus `scripts/verify_release_automation.sh` when touching automation files. Update `automation/STATUS.md`, `automation/RUN_LOG.md`, and `automation/BACKLOG.yaml` with the result.
