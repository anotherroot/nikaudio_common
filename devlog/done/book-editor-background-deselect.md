# Book Editor Background Deselect

**Status:** done · **Area:** `nikaudio-web` (book editor)

## Goal

Make editor background clicks clear selection in select/multiselect modes, while edit mode exits to
single selection without changing the selected block.

## Decisions

- Handle clicks on the central editor scroll surface, not globally, so sidebars/search/toolbar are
  not affected.
- Ignore clicks that originate from blocks, buttons, links, and form/editable controls.
- Add an explicit `exitEditMode()` state command instead of reusing Escape handling indirectly.
- When a block is clicked during edit mode, exit edit mode and keep the previous selection rather
  than selecting the clicked block.

## Log

## 2026-07-01 — Completed

- Added central editor-surface click handling for background deselect.
- Added edit-mode block click handling that exits edit mode without changing selected block.
- Added tests for single select, mass select, edit background clicks, edit clicks on another block,
  and ignored action targets.
- Verified with `nix develop -c npm test -- --watch=false --browsers=ChromeHeadless`,
  `nix develop -c npm run format:check`, and `nix develop -c npm run lint`.
