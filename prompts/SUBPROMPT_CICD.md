# CI/CD Subprompt

You are executing a PersonaOS CI/CD task.

Defaults:

- GitHub Actions
- self-hosted macOS runner for Xcode build/test/archive
- no signing secrets in Git

Expected outputs:

1. `.github/workflows/macos-build.yml`
2. `.github/workflows/macos-release.yml`
3. `ci/README.md`
4. optional `scripts/bootstrap_ci_keychain.sh`
5. required secret/environment variable list

Rules:

1. Build workflow covers Debug build, tests, and UI smoke when available.
2. Release workflow covers archive, export, metadata sync, and upload handoff.
3. If upload cannot run, publish the release bundle as an artifact.
4. Workflows must not depend on private local paths.
5. Preserve logs and xcresult artifacts on failure.

Output:

```text
STATUS:
TASK_ID:
WORKFLOWS_ADDED:
SECRETS_REQUIRED:
COMMANDS_RUN:
VALIDATION_RESULT:
ARTIFACTS:
ROLLBACK_ACTION:
NEXT_TASK:
```
