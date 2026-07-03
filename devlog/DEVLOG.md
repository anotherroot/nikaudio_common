# Nikaudio Dev Log

This is the project-level index of the development log. Each feature has its own file
under `doing/`, `waiting/`, or `done/`, holding a short goal/decisions header plus a
reverse-chronological, timestamped entry log. Move a feature file between the folders as
its status changes, and keep the link here in sync.

See `nikaudio-common/AGENTS.md` (Dev Log section) for how to maintain these files.

## Doing

- [UI Revamp + Dark Mode](doing/ui-revamp.md)
  — modern, coherent look for the whole frontend via semantic color tokens + class-based dark
  mode; retire the gradient-era screens, keep the editor/player design language.
- [Public Domain Books](doing/public-domain-books.md)
  — admin-curated public-domain catalog, user "public book" clones (text-locked), shared audio
  versions with like/dislike ranking, disable-block, and create-book-from-audiobook.

## Waiting

_(none)_

## Done

- [Pronunciation Info Panel And Builder](done/pronunciation-info-panel-and-builder.md)
  — larger Misaki English phoneme reference panel plus row-level pronunciation builder insertion UI.
- [Audio Player view](done/audio-player-view.md)
  — real listening UI: floating transport bar, click-seek, ±10s/±paragraph, current-block
  highlight + progress fill, and auto-scroll following playback over the paginated chunks.
- [Shared Scroll Engine](done/shared-scroll-engine.md)
  — one generic virtual-scroll strategy shared by the book editor and audio player.
- [Sample Request Pipeline](done/sample-request-pipeline.md)
  — generate an audio sample from one or many selected blocks, queued/played like a book and marked as a sample.
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
