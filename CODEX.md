# KeepingUp Codex Guide

This file is a working instruction document for future Codex sessions.
It describes the current KeepingUp product behavior, UX direction, and technical guardrails.
It is not a generic README.

## Project Overview

KeepingUp is a native macOS menu bar productivity app built with SwiftUI.

The app should live primarily in the macOS menu bar and should not drift back toward a normal dock-first or window-first app model.

The core experience is:
- quick daily task visibility
- lightweight task management
- gentle reminders on login, wake, or unlock
- fast capture of tasks

The UX should feel:
- native to macOS
- lightweight
- calm
- low-friction
- readable within a few seconds

## Product Direction

The menu bar popover is the main everyday app surface.

The Settings UI must live in a separate Settings window, not inside the main task view.

The Settings window must:
- be resizable
- remain usable at smaller sizes
- avoid clipping content
- use scrolling instead of fixed-size layouts when necessary

Quit belongs in Settings.
Do not reintroduce Quit into the main task popover.

The main menu bar popover should stay task-focused.
Do not turn it into a settings surface.

## Menu Bar UX Rules

The menu bar popover should emphasize today’s tasks or the most relevant near-term tasks.

The compact task UI should stay simple:
- clear task visibility
- quick completion toggles
- lightweight task creation
- minimal destructive controls

Task colors and status indicators should stay clear but not noisy.

Do not overload the compact menu bar UI with too much information.

Any reminder popup or transient overlay must not be a 1:1 copy of the menu bar dropdown.

## Settings Rules

Settings are a separate app surface for configuration and app-level actions.

Settings currently contain or may contain:
- launch at login
- reminder enablement
- reminder presentation style
- developer-mode reminder controls
- notification settings helper actions
- quit

Do not move these controls back into the main menu bar panel unless a product change explicitly asks for it.

## Notification Modes

KeepingUp supports two reminder presentation modes:
- custom in-app center pop-up
- standard macOS notification

Only one notification presentation mode should be active for a reminder event.
Never show both at the same time.

If the selected mode is:
- custom popup: only show the custom popup
- macOS notification: only schedule the system notification

Do not leave fallback logic that can cause both paths to run.

## Reminder Business Logic

On login, wake, or unlock, the app may show a gentle greeting or daily-focus reminder.

Reminder behavior should feel helpful, not spammy.
The copy should feel warm and concise rather than alarm-like.

Rules:
- reminders should not feel repetitive
- cooldown logic should prevent repeated firing too often
- developer mode may adjust or disable cooldowns for testing
- cooldown-disabled mode must fully bypass cooldown suppression

Lifecycle triggers should stay consistent across:
- app launch
- session active after unlock
- wake from sleep
- other app-level reminder triggers

When changing reminder behavior, keep these concerns aligned:
- lifecycle event trigger
- cooldown rules
- selected presentation mode
- task availability
- permission state for system notifications

## Custom Popup Rules

The custom center popup is a lightweight transient notification.
It is not a mini app window and not a duplicate of the menu bar panel.

The popup should:
- feel like a calm macOS-style notification overlay
- use a small app label, one primary message, and optional supporting text
- use warm, human greeting copy that changes with time of day
- show at most one highlighted task, or summarize if multiple tasks exist
- avoid checklist rows, separators, and cloned app-panel UI
- allow dismiss by clicking anywhere on it
- optionally keep a subtle close button
- auto-dismiss after a reasonable delay
- optionally pause dismiss on hover
- avoid stealing focus from the current app
- animate in and out smoothly

The popup should be readable in 1 to 2 seconds.

## Standard macOS Notification Rules

Standard system notifications are valid as an alternative reminder style.

Do not try to force banner persistence in code.
Banner vs alert behavior is controlled by the user’s macOS notification settings.

If needed, provide a helper button that opens macOS Notification Settings rather than trying to override system behavior.

## Task Creation and Shortcuts

KeepingUp is intended to support fast task capture through App Intents, Shortcuts, and Spotlight.

The current direction is:
- expose an “Add Task” shortcut
- allow shortcut-based task creation without opening the main app UI
- save directly into the app’s data store
- refresh menu bar state when a task is created externally

Validation rules for shortcut-based task creation must match manual entry:
- trim whitespace
- reject blank titles
- use sensible defaults for optional fields
- reuse the same validation and persistence rules as manual task creation

Do not require opening the main app window just to create a task from a shortcut.

Future shortcut expansion may include things like:
- complete task
- show today’s tasks

But changes should keep the shortcut flow fast and native.

## Architecture Guidance

Keep responsibilities separated.

Prefer small focused components over large mixed-responsibility views.

The major concerns should stay distinct:
- settings UI
- task persistence
- reminder delivery
- lifecycle event observation
- menu bar task UI
- App Intents / shortcut entry points

Workspace and system lifecycle wiring should be centralized in a long-lived app-level observer.
Do not scatter unlock, wake, or session-active observers across temporary views or settings screens.

Do not duplicate reminder logic across multiple UI layers.
Reminder decision-making should stay centralized so cooldown and mode selection remain correct.

## UX Guardrails

Default to native-feeling macOS behavior.

Prefer calm, readable, compact interfaces over busy app-like panels.

Do not force precise clicks for transient UI when a broader dismiss behavior is more user-friendly.

Do not add extra controls unless they clearly improve speed or clarity.

Every quick surface should be understandable within a few seconds.

## Implementation Guardrails

Do not:
- reintroduce settings into the main menu bar task panel
- show both custom popup and macOS notification for the same event
- build the custom popup as a duplicate of the menu bar view
- make the Settings window fixed-size if content can be clipped
- require opening the main app window for shortcut-based task creation
- scatter lifecycle observers into short-lived UI objects
- silently change reminder cooldown behavior without updating the product rules here

Preserve existing app behavior unless a requested change explicitly replaces it.

## Developer Workflow

Future Codex sessions should read this file first and preserve the current UX and product direction.

When business logic, behavior, or product direction changes, update this file in the same change set.

Implement roadmap work in small, reviewable feature branches rather than broad rewrites.
Prefer one roadmap slice per branch and MR.

If UI is introduced ahead of full behavior, leave the unfinished controls clearly disabled or route them to an intentionally blank placeholder state.

Default to TDD for new functionality:
- add or update tests before changing behavior when practical
- every feature branch should include automated coverage for the new behavior it introduces
- a roadmap step is not complete until acceptance criteria and tests both pass

Keep this file focused on:
- real app behavior
- design intent
- technical guardrails
- regression prevention

Do not turn this file into setup notes, generic architecture theory, or a user-facing README.

## Current Technical Notes

The app is a macOS `MenuBarExtra` app.

The app uses local persistence and should remain simple.
Avoid introducing cloud sync, networking, or unnecessary infrastructure unless explicitly requested.

Launch-at-login, reminder delivery, menu bar UI, and task persistence should remain lightweight and beginner-friendly.

The developer is new to Swift.
Prefer clear, explicit code and brief comments where platform behavior is non-obvious.
