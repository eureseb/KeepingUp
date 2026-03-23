# KeepingUp Implementation Playbook

This document is the step-by-step delivery guide for the roadmap. It is intentionally detailed so each feature branch can be built and reviewed in isolation.

## Global Rules

### Branching

- Create one feature branch per roadmap slice.
- Keep each MR scoped to one user-visible capability.
- Do not rewrite adjacent systems unless the branch explicitly owns that refactor.

### TDD Policy

- Start each roadmap slice by writing or updating failing tests when practical.
- Add tests for user-facing behavior, parsing rules, sorting rules, persistence, and regression-prone edge cases.
- Do not mark a roadmap step complete until the implementation and its new tests both pass.

### Definition of Done

- Acceptance criteria are met.
- New functionality has automated test coverage.
- Existing tests still pass in the available environment.
- Product or workflow docs are updated in the same branch.
- The MR description clearly states scope, risks, and out-of-scope items.

### Guardrails

- Do not overwrite unrelated files just because they are convenient to edit.
- Keep placeholder or incomplete UI disabled.
- Keep the menu bar UI compact and task-focused.
- Preserve current behavior unless the roadmap step explicitly replaces it.

## Phase 1: Reminder Polish

### Goal

- Make login, wake, and unlock reminders feel warm, concise, and readable.

### Implementation Steps

1. Create a shared reminder message builder so popup and notification copy stay aligned.
2. Add time-of-day greeting behavior.
3. Polish the popup surface for readability, contrast, and calmer visual treatment.
4. Keep the popup lightweight: one primary message plus optional supporting context.
5. Update product guidance docs in the same branch.

### Acceptance Criteria

- Reminder copy changes with time of day.
- Popup text is readable against the chosen background.
- The popup no longer looks like a generic alert clone.
- Popup and notification paths do not drift into different language styles.
- Reminder behavior still respects the existing cooldown and presentation mode rules.

### Required Tests

- Unit tests for morning, afternoon, and evening copy.
- Unit tests for zero, one, and many open-task states.
- Regression checks that notification and popup paths use the same copy source.

## Phase 2: Task Model and Persistence Foundation

### Goal

- Introduce a proper local task data layer that can support future fields and migrations cleanly.

### Implementation Steps

1. Write failing tests for migration and repository behavior.
2. Introduce the repository abstraction.
3. Add the structured local store.
4. Add one-time migration from legacy `UserDefaults` tasks.
5. Extend the task model with due date, priority, timestamps, and optional parser metadata.
6. Keep non-task preferences isolated from the task store unless that branch explicitly owns them.

### Acceptance Criteria

- Existing tasks survive migration.
- New tasks read and write through the repository, not through direct `UserDefaults` array storage.
- The app still launches with old user data present.
- The expanded model compiles cleanly through UI, reminders, and intents.

### Required Tests

- Migration test from legacy `UserDefaults` payloads.
- Repository CRUD tests.
- Tests for default field values on migrated and newly created tasks.

## Phase 3: Manual Deadlines and Priority

### Goal

- Add due dates and priority to the everyday task workflow.

### Implementation Steps

1. Write failing tests for urgency ordering and due-state color rules.
2. Add manual deadline editing.
3. Add manual priority editing.
4. Add urgency sorting and the agreed color thresholds.
5. Keep compact menu bar layout readable even with new metadata.

### Acceptance Criteria

- Users can manually set, edit, and remove deadlines.
- Users can set low, medium, or high priority.
- Incomplete tasks sort by urgency before non-urgent tasks.
- Overdue, near-due, and future tasks are visually distinct.

### Required Tests

- Persistence tests for due date and priority.
- Sorting tests for overdue, due soon, upcoming, and no-deadline tasks.
- UI or view-model tests for color/urgency mapping where practical.

## Phase 4: Natural-Language Task Creation

### Goal

- Turn one English sentence into a task with structured metadata.

### Implementation Steps

1. Write failing parser tests from real examples before coding parser rules.
2. Add parser settings for workday start, workday end, and end-of-day defaults.
3. Implement local parsing only.
4. Add confirmation or blocking behavior for vague phrases.
5. Reuse the parser in app UI and shortcut entry points.

### Acceptance Criteria

- Clear phrases extract title, deadline, and priority.
- `EOD` maps to the configured end-of-day setting.
- Vague phrases like `this week` do not silently create risky deadlines.
- Parser output is consistent across manual and shortcut-based creation.

### Required Tests

- Parser tests for explicit times, `EOD`, and no-priority inputs.
- Parser tests for vague phrases that must require confirmation.
- Regression test for the “reply to sir John...” style example.

## Phase 5: Spotlight and Shortcut Task Updates

### Goal

- Let App Intents reschedule, reprioritize, and complete tasks through Shortcuts and Spotlight.

### Implementation Steps

1. Write failing tests for task matching and ambiguity handling.
2. Add task lookup rules with exact match first and fuzzy fallback second.
3. Add separate intents for rescheduling, priority changes, and completion.
4. Reuse the parser rules from Phase 4.
5. Fail safely when multiple tasks are plausible.

### Acceptance Criteria

- A task can be rescheduled from Shortcuts/Spotlight.
- A task can be reprioritized from Shortcuts/Spotlight.
- A task can be marked complete from Shortcuts/Spotlight.
- Ambiguous task names do not silently update the wrong task.

### Required Tests

- Task-matching tests for exact, fuzzy, and ambiguous cases.
- Intent-level tests where practical.
- Regression tests for parser reuse in update flows.

## Phase 6: Calendar and Future Device Exploration

### Goal

- Explore a calendar/agenda surface only after task metadata and shortcuts are stable.

### Implementation Steps

1. Decide whether the calendar is a lightweight read-only agenda or an editable planning surface.
2. Start with a placeholder or read-only prototype if the full interaction model is not ready.
3. Keep sync and multi-device support out of scope unless the branch explicitly owns that work.

### Acceptance Criteria

- The calendar surface does not replace or overload the main menu bar workflow.
- The prototype is clearly scoped and does not imply sync that does not exist.
- Existing task behavior remains unchanged outside the new surface.

### Required Tests

- Tests for date grouping and task inclusion rules.
- Tests for any new filters, grouping logic, or agenda summaries.

## MR Checklist

Every MR should include:

- User-facing summary
- Exact scope
- Acceptance criteria covered
- Tests added or updated
- Manual verification notes
- Out-of-scope list
- Follow-up items for the next branch
