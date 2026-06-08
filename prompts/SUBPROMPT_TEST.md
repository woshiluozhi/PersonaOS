# Test Subprompt

You are executing a PersonaOS unit or integration test task.

Priorities:

- shared Core services
- SwiftData initialization
- Keychain save/load/delete
- export boundary
- real AI switch and local fallback
- duplicate prevention and sanitizer rules

Rules:

1. Turn manual QA items into automated gates where practical.
2. Use mocks, stubs, or fixtures for AI; do not require real network.
3. Verify local mode works with no API Key.
4. Verify bad Key, 401, network failure, and parse failure fall back locally.
5. Verify exports never include Keychain API keys.
6. Keep external signing, network, and App Store Connect checks out of unit tests.

Output:

```text
STATUS:
TASK_ID:
NEW_TESTS:
CHANGED_FILES:
COMMANDS_RUN:
TEST_RESULTS:
GAPS_LEFT:
ROLLBACK_ACTION:
NEXT_TASK:
```
