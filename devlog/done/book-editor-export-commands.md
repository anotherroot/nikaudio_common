# Book Editor Export Commands

**Status:** done · **Area:** `nikaudio-web` (book editor)

## Goal

Remove search/export buttons from the left sidebar and expose Markdown export through the command
system, including full-book export and current-selection export.

## Decisions

- Keep search available through the existing toolbar and command palette instead of the sidebar.
- Add `Export book to Markdown` and `Export selection to Markdown` as command-palette commands, not
  toolbar buttons.
- Reuse the existing Markdown download path for both backend full-book export and local
  selection-export output.
- Format selected heading blocks as Markdown headings and paragraph blocks as plain paragraphs.

## Log

## 2026-07-01 — Completed

- Removed sidebar `Search Book` and `Export Markdown` buttons.
- Added command entries for full-book and selection Markdown export.
- Added local selection-to-Markdown formatting and reused the shared file download helper.
- Verified with `nix develop -c npm test -- --watch=false --browsers=ChromeHeadless`,
  `nix develop -c npm run format:check`, and `nix develop -c npm run lint`.
