# Implementation Subprompt

You are executing a PersonaOS implementation task.

Read first:

- `automation/DECISIONS.yaml`
- `automation/STATUS.md`
- `automation/BACKLOG.yaml`
- current task input

Rules:

1. Modify only `ALLOW_PATHS`.
2. Prefer shared Core extraction before macOS UI.
3. Replace risky brand/IP names with original neutral names unless owner rights evidence exists.
4. Keep commerce code feature-flagged; default is paid upfront.
5. Establish a rollback point before risky project-file or target changes.
6. Limit one run to a small coherent change; split if more than 12 files are required.
7. Never write secrets to source, scripts, config, logs, or docs.
8. Run targeted build or tests after changes.

Output:

```text
STATUS: success|partial|blocked|failed
TASK_ID:
SUMMARY:
CHANGED_FILES:
COMMANDS_RUN:
TEST_RESULTS:
ARTIFACTS:
ROLLBACK_ACTION:
NEXT_TASK:
```
