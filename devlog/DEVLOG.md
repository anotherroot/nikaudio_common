# Nikaudio Dev Log

This is the project-level index of the development log. Each feature has its own file
under `doing/`, `waiting/`, or `done/`, holding a short goal/decisions header plus a
reverse-chronological, timestamped entry log. Move a feature file between the folders as
its status changes, and keep the link here in sync.

See `nikaudio-common/AGENTS.md` (Dev Log section) for how to maintain these files.

## Doing

_(none)_

## Waiting

_(none)_

## Done

- [Book Editor Block-Index Autofetch](done/book-editor-block-index-autofetch.md)
  — load the next block batch when scrolling reaches the last 50 loaded blocks.
- [Book Editor Unsaved Navigation Guard](done/book-editor-unsaved-navigation-guard.md)
  — warn before leaving dirty/saving editor state, with save status in the in-app dialog.
- [Block Toolbar + Command Palette + Undo/Redo](done/block-toolbar-command-palette-undo.md)
  — bottom toolbar, searchable command palette, and FE-only undo/redo for the book editor.
- [Book Editor Toolbar + Clipboard + Merge](done/book-editor-toolbar-clipboard-merge.md)
  — mode-aware toolbar, disabled command reasons, system clipboard paste/copy/cut, and merge.
