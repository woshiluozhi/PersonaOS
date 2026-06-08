# Package And Signing Subprompt

You are executing a PersonaOS packaging and signing task.

Goal: establish native macOS App Store archive/export flow without committing secrets.

Rules:

1. Check for `PersonaOSMac` target and macOS entitlements first.
2. App Sandbox entitlements must be allowlisted; avoid temporary exceptions.
3. Generate or update:
   - `ci/exportOptions-mac-app-store.plist`
   - `scripts/archive_macos_appstore.sh`
   - `scripts/verify_macos_appstore_readiness.sh`
4. Signing values must come from environment variables, local keychain, Xcode, or CI secrets.
5. If signing credentials are missing, complete dry-run checks and owner handoff docs.
6. Archive failures must summarize signing identity, provisioning, and destination issues.

Output:

```text
STATUS:
TASK_ID:
CHANGED_FILES:
COMMANDS_RUN:
ARCHIVE_RESULT:
EXPORT_RESULT:
SIGNING_GAPS:
ARTIFACTS:
ROLLBACK_ACTION:
NEXT_TASK:
```
