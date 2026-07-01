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

- [Header Avatar Icon](done/header-avatar-icon.md)
  — replace the placeholder header user circle letter with an avatar icon.
- [Book Editor Go-To-Start Command](done/book-editor-go-to-start-command.md)
  — remove sidebar start navigation and expose it as a command-palette action.
- [Book Editor Export Commands](done/book-editor-export-commands.md)
  — remove sidebar search/export buttons and expose book/selection Markdown export through commands.
- [Book Editor Background Deselect](done/book-editor-background-deselect.md)
  — clear selection from the editor background and exit edit mode without changing selection.
- [Book Editor Block-Index Autofetch](done/book-editor-block-index-autofetch.md)
  — load the next block batch when scrolling reaches the last 50 loaded blocks.
- [Book Editor Unsaved Navigation Guard](done/book-editor-unsaved-navigation-guard.md)
  — warn before leaving dirty/saving editor state, with save status in the in-app dialog.
- [Block Toolbar + Command Palette + Undo/Redo](done/block-toolbar-command-palette-undo.md)
  — bottom toolbar, searchable command palette, and FE-only undo/redo for the book editor.
- [Book Editor Toolbar + Clipboard + Merge](done/book-editor-toolbar-clipboard-merge.md)
  — mode-aware toolbar, disabled command reasons, system clipboard paste/copy/cut, and merge.
