# project-progress

A pane in Claude Code that shows every project thread's progress, with the items that need Tim at the top. It refreshes every 30 seconds and puts a one-line summary in the status line. `/progress` opens it again.

## Status files

Each thread writes one file, `<threadId>.json`, to the status folder (default `C:/Users/Arceu/repos/.claude-progress`, set by the `statusFolder` option). Writing the same file again replaces it.

```json
{
  "schema": 1,
  "threadId": "cmsg_...",
  "title": "Fix Safari export button",
  "state": "working",
  "waitingOn": "Your OK to push",
  "currentStep": "Write the failing test",
  "stepsDone": 1,
  "stepsTotal": 4,
  "updatedAt": "2026-11-18T03:55:00Z"
}
```

`state` is one of `needs_tim`, `review_ready`, `failed`, `working`, `stopped`, `done`. `waitingOn` and `currentStep` are optional. Files that don't parse are skipped. Finished items drop off after a day, and a working item with no update for two hours shows as quiet.

## Checks

`claude plugin test .` and `claude plugin validate .`
