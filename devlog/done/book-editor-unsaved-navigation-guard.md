# Book Editor Unsaved Navigation Guard

**Status:** done · **Area:** `nikaudio-web` (book editor)

## Goal

Protect users from losing book editor changes when navigating away or refreshing while changes are
dirty or currently saving.

## Decisions

- Angular route changes use an in-app modal so it can show live save state.
- Browser refresh/close uses `beforeunload`, because browsers only allow their native prompt and
  do not permit custom dialog content or buttons during page unload.
- The guard blocks when the editor is dirty, saving, or syncing.
- The dialog exposes Stay, Leave, and Save. Save is disabled while saving and changes label to
  `Saving...` while a save is running and `Saved` once the editor is clean.

## Log

## 2026-07-01 — Completed

- Added a `CanDeactivate` guard for `/book/:id`, delegated to the active editor component.
- Added a component-owned leave dialog that stays open while autosave/save state changes and updates
  its Save button label/disabled state from editor signals.
- Added native `beforeunload` protection for browser refresh/close.
- Verified with `nix develop -c npm test -- --watch=false --browsers=ChromeHeadless`,
  `nix develop -c npm run format:check`, and `nix develop -c npm run lint`.

## 2026-07-01 — Started implementation

- Adding a route `CanDeactivate` guard for `/book/:id` and a component-owned confirmation modal.
- The existing autosave signals (`isDirty`, `isSaving`, `isSyncing`, `saveStatus`) will drive the
  dialog state so autosave progress is visible while the dialog is open.
