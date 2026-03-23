# MR: Phase 3 Wrap-Up for Deadlines, Focus, Alerts, and Cleanup

## Summary

This branch finishes the broader Phase 3 slice around manual deadlines, priority, filter/focus behavior, due alerts, reorder fallback controls, and completed-task cleanup.

The current shipped popover behavior is:
- open in `Today` on every popover entry
- use a single `Upcoming` quick chip to toggle into and out of future-task filtering
- use a separate `Focus` toggle for a calmer today-only view
- keep unplanned tasks accessible

## Why

- The branch grew beyond the original deadlines-and-priority slice and the docs needed to catch up with the UX that actually shipped.
- The app now has multiple Phase 3 behaviors that depend on the same deadline and ordering model: due alerts, menu bar urgency, focus filtering, reorder fallback, and reminder selection.
- Test coverage needed to stay centered on deterministic unit/view-model behavior rather than brittle menu bar automation.

## What Changed

- Added deadline, explicit-time, priority, pin, and manual-order metadata to the task flow with backward-compatible decoding.
- Added shared scheduling and urgency logic for popover sections, reminder selection, due alerts, and menu bar icon state.
- Refined the popover to Today-first entry, a single `Upcoming` quick chip, a separate `Focus` toggle, and reorder fallback controls instead of drag-and-drop.
- Added a separate due-alert setting plus one-shot macOS notifications for future near-due deadlines.
- Added optional daily auto-delete cleanup for completed tasks and in-popover success feedback for task completion/all-done states.
- Updated docs and tests so they describe and verify the current shipped behavior rather than the earlier Phase 3 proposal wording.

## Out of Scope

- Natural-language task parsing
- Shortcut-based task updates
- Calendar or agenda views
- Reintroducing drag-and-drop reordering
- Expanding UI automation around the menu bar extra in this environment

## Testing

- `xcodebuild test -scheme KeepingUp -destination 'platform=macOS' -derivedDataPath /tmp/KeepingUpDerivedData`
- Unit coverage includes migration defaults, due alerts, urgency state, Today-first reset behavior, `Upcoming` quick-filter toggling, focus fallback, manual ordering, reminder selection, and completed-task cleanup.
- Menu bar UI automation remains intentionally minimal because the menu bar extra is not reliably exposed to macOS UI automation here.
- The launch UI test is treated as non-blocking and skipped for the same reason, so Phase 3 confidence comes primarily from unit/view-model coverage plus manual verification.

## Review Notes

- Focus review on whether the docs now match the actual Today-first + `Upcoming` chip + Focus toggle behavior.
- Confirm reminder selection, due alerts, and menu bar urgency still follow the shared scheduling logic.
- Confirm completed-task cleanup and completion feedback feel additive without overloading the compact popover.
