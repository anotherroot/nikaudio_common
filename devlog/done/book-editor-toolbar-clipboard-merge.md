# Book Editor Toolbar + Clipboard + Merge

**Status:** done (automated checks green; in-app clipboard permission behavior pending user
validation) · **Area:** `nikaudio-web` (book editor)

## Goal

Refine the book editor command toolbar so it is available whenever sidebars are open, shows
mode-specific commands, keeps the command palette complete with disabled reasons, and supports
merge plus system clipboard copy/cut/paste across selection and text-edit modes.

## Decisions

- Toolbar visibility: shown whenever sidebars are open.
- Toolbar command sets are mode-aware: book, single-select, mass-select, and textarea-edit modes.
- Merge is contiguous-only and joins selected block content with a single space.
- System clipboard is the source of truth for copy/cut/paste.
- Select/mass paste splits clipboard text into blocks by non-empty lines.
- Edit-mode paste normalizes clipboard newlines/repeated whitespace into single spaces.

## Log

## 2026-07-01 — Implemented mode-aware toolbar, merge, and system clipboard

- Added command metadata for toolbar modes, async command runs, and disabled reasons. The toolbar
  now renders whenever sidebars are open and filters commands by editor mode.
- Added search, merge, toggle-heading, and split-at-cursor commands. Merge is contiguous-only,
  keeps the first block identity/metadata, joins content with spaces, and deletes the remaining
  selected blocks.
- Replaced the in-app clipboard as paste source with `navigator.clipboard`: copy/cut write
  selected blocks as newline-separated text; select/mass paste reads lines into new blocks; edit
  paste collapses whitespace into inline text.
- Added a component callback bridge for DOM-dependent command actions: opening search, splitting
  at the active textarea cursor, and inserting paste text at the active textarea selection.
- Added disabled command reasons in the command palette and toolbar titles. Added focused tests
  for state, command service, component bridge, and block paste emission.
- Verified focused specs, the full frontend test suite, format check, lint, and production build.

## 2026-07-01 — Started implementation

- User requested toolbar visibility outside selection, mode-specific toolbar commands, merge,
  disabled command explanations in the palette, and system clipboard semantics.
- Implementation will keep the command registry as the single command source and add a small
  component callback bridge only for DOM-dependent actions such as search and edit-caret paste.
