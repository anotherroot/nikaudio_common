# Book Editor Go-To-Start Command

**Status:** done · **Area:** `nikaudio-web` (book editor)

## Goal

Remove the left-sidebar `Go to start` button and expose the same loaded-window navigation through
the command system.

## Decisions

- Keep the existing inline `Load previous`/`Go to start` controls above the block list unchanged.
- Remove only the sidebar copy of `Go to start`.
- Add `Go to start` as a command-palette command, not a toolbar button.
- Gate command availability on `startBlock() > 0`, matching the old sidebar visibility rule.

## Log

## 2026-07-01 — Completed

- Removed the sidebar `Go to start` button from the book-info panel.
- Added a `Go to start` navigate command wired to the existing route update flow.
- Added tests for the missing sidebar button and command execution.
- Verified with `nix develop -c npm test -- --watch=false --browsers=ChromeHeadless`,
  `nix develop -c npm run format:check`, and `nix develop -c npm run lint`.
