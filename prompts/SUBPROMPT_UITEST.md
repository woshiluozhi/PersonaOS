# UI Test Subprompt

You are executing a PersonaOS UI smoke test task.

Minimum macOS 1.0 scenarios:

1. First launch and seeded/empty state.
2. Navigate Dashboard, Tasks, Chat, Memory, Review, and Settings.
3. Create a quest, create a task, complete and reopen a task.
4. Send a local-mode chat message.
5. Export local JSON.
6. Open support/privacy links.
7. Confirm destructive actions.

Rules:

1. Use a dedicated UI test target.
2. Keep tests stable, idempotent, and CI-friendly.
3. Prefer route-level smoke checks over brittle pixel assertions.
4. Preserve screenshots and xcresult logs on failure.

Output:

```text
STATUS:
TASK_ID:
UITEST_TARGET:
SCENARIOS_COVERED:
CHANGED_FILES:
COMMANDS_RUN:
TEST_RESULTS:
ARTIFACTS:
ROLLBACK_ACTION:
NEXT_TASK:
```
