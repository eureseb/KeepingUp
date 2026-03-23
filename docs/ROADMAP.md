# KeepingUp Roadmap

This roadmap is the implementation order for expanding KeepingUp without turning the app into a large rewrite.

## Delivery Rules

- Keep the app macOS-first and menu-bar-first.
- Ship one roadmap slice per branch and MR.
- Do not bundle unrelated changes together just because they touch nearby files.
- If a UI surface appears before behavior is ready, keep it disabled or send it to an intentionally blank placeholder state.
- Add or update tests for every new user-facing behavior.

## Recommended Branching

1. `add/reminder-polish`
2. `add/task-storage-foundation`
3. `add/deadlines-and-priority`
4. `add/natural-language-capture`
5. `add/spotlight-task-updates`
6. `add/calendar-exploration`

## Phase Order

### Phase 1: Reminder Polish

Status: current branch

Goal:
- Make unlock/login reminders feel more human and less like raw alerts.

Scope:
- Time-aware greeting copy
- Calmer popup presentation
- Shared reminder messaging logic for popup and notification paths

### Phase 2: Task Model and Persistence Foundation

Goal:
- Move task persistence off the current `UserDefaults` array and onto a structured local store.

Scope:
- Introduce a repository layer
- Add migration from existing `UserDefaults` tasks
- Prepare the model for deadlines, priority, and natural-language metadata

Dependency:
- Required before deadline, priority, and NLP-heavy features

### Phase 3: Manual Deadlines and Priority

Goal:
- Let tasks carry due dates and priority in the normal app workflow.

Scope:
- Manual due date editing
- Priority editing
- Urgency-based ordering and color states

Dependency:
- Requires Phase 2

### Phase 4: Natural-Language Task Creation

Goal:
- Let one English sentence become a task title, deadline, and priority.

Scope:
- Local parsing only
- Confirmation for vague phrasing
- Shared parser rules for app UI and shortcuts

Dependency:
- Requires Phase 2 and should build on Phase 3 UI semantics

### Phase 5: Spotlight and Shortcut Task Updates

Goal:
- Reschedule, deprioritize, or complete tasks with English through App Intents and Shortcuts.

Scope:
- Reschedule intent
- Priority-change intent
- Complete-task intent
- Shared task matching rules

Dependency:
- Requires Phase 2 and parser work from Phase 4

### Phase 6: Later Exploration

Goal:
- Explore calendar/agenda surfaces and future multi-device readiness after the task model is stable.

Scope:
- Calendar prototype
- Storage evolution discussion
- Future sync evaluation

Dependency:
- Only after Phases 2 through 5 are stable
