# MR: Reminder Polish

## Summary

This MR is the first small roadmap slice. It improves the tone and readability of login, wake, and unlock reminders without changing task storage, task structure, or other unrelated systems.

## Why

- The existing reminder experience felt too close to a plain alert.
- The product direction calls for warmer, more human reminder copy.
- This branch keeps the first change reviewable before we touch persistence, deadlines, priority, or natural-language parsing.

## What Changed

- Added a shared reminder message builder so popup and notification copy stay aligned.
- Added time-of-day greeting copy.
- Updated the popup presentation to feel calmer and improve readability.
- Removed the panel-level shadow/border artifact from the custom popup path.
- Added reminder-copy tests.
- Updated internal product guidance in `CODEX.md`.

## Out of Scope

- No storage migration
- No deadline or priority support
- No natural-language task parsing
- No new shortcut intents
- No calendar work

## Testing

- `xcodebuild build -scheme KeepingUp -destination 'platform=macOS' -derivedDataPath /tmp/KeepingUpDerivedData`
- Added unit tests for morning, afternoon, and all-clear reminder copy states.
- Full `xcodebuild test` is currently sandbox-limited in this environment because the macOS test runner and distributed notification path are blocked.

## Review Notes

- Focus review on the shared reminder copy flow and popup readability.
- Do not expect broader architecture changes in this branch.
- Existing unrelated local modifications were intentionally left untouched.

## Follow-Up Branch

- `add/task-storage-foundation`
