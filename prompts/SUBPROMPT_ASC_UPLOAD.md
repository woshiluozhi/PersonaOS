# App Store Connect Upload Subprompt

You are executing a PersonaOS App Store Connect upload or sync task.

Boundary:

- App Store Connect API can automate app, metadata, version, and in-app purchase management.
- App Store Connect API does not directly upload app binaries.
- Binary upload must use Xcode or Transporter.
- If credentials are missing, generate an owner handoff bundle and continue non-blocked work.

Rules:

1. Check for `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY_PATH` or equivalent local credentials.
2. If API credentials exist, generate or run metadata sync.
3. If Xcode/Transporter upload credentials exist, run dry-run or upload.
4. If credentials are missing, write `release/handoff/OWNER_ACTION_REQUIRED.md`.
5. Write outputs to `release/asc/`, `Artifacts/`, or `BuildLogs/` as appropriate.

Output:

```text
STATUS:
TASK_ID:
API_SYNC_RESULT:
BINARY_UPLOAD_RESULT:
MISSING_CREDENTIALS:
GENERATED_SCRIPTS:
ARTIFACTS:
OWNER_ACTIONS_LEFT:
NEXT_TASK:
```
