# Block Toolbar + Command Palette + Undo/Redo

**Status:** done (automated checks green; in-app E2E pending user validation) · **Area:**
`nikaudio-web` (book editor)

## Goal

Give the book editor a bottom toolbar of block operations, a searchable command palette for
the full command set, and FE-only undo/redo (Ctrl+Z / Ctrl+Y). Backend versioning is a
separate future feature and out of scope here.

## Decisions

- **Undo granularity:** operation-level. Each command = one undo step. In-block typing uses
  the browser's native textarea undo; committing an edit (leaving the block) records one
  `edit` step.
- **Toolbar visibility:** tied to sidebars — shown only when `sidebarsOpen()` and a
  selection exists (`select` or `mass`). Collapsing sidebars hides it.
- **History robustness:** blocks get a stable client-side `uid`; in-place block mutations
  become immutable. History snapshots key off `uid`, so undo survives the 1.2s autosave that
  maps `local_id → id` and rebuilds block objects.
- **Clipboard:** in-app clipboard signal for v1; system clipboard later.

## Phases

0. Devlog infrastructure (this file + convention).
1. Stable block `uid` + immutable mutations (no UX change).
2. Command registry + new block operations (move/duplicate/cut/copy/paste).
3. Bottom toolbar + command palette UI.
4. Undo/redo history.

## Log

## 2026-07-01 — Fix: undo/redo did not mark dirty or persist

- Bug (user-reported): after deleting a block or editing text and letting it save, clicking
  undo reverted the UI but left the document "clean", so autosave skipped it and the server
  kept the deleted/edited state.
- Root cause: snapshots captured the per-block dirty flags as-is, so `restore()` produced a
  state whose `isDirty()` was false even though the local state had diverged from the server.
  Also, the backend hard-deletes block rows (`nikaudio-be .../books/update.go`) and
  updates/creates by id/local_id — so undoing an already-saved delete can't just re-send the
  old id; the row is gone and must be re-created.
- Fix: `restore()` now re-derives save flags by diffing the restored blocks against the set of
  ids the server currently holds (`savedBlockIds`, maintained on load/save):
  - server still has the block → keep its id, mark dirty only if the restore changed its
    content/type/voice/lang;
  - server no longer has it (or never did) → re-create as a new block (drop id, fresh
    local_id, keep the stable uid);
  - server has a block the restored state dropped → add it to `deletedBlocks`;
  - order-dirty set when the restored uid order differs.
  This makes `isDirty()` reflect real divergence, so autosave runs and reproduces the restored
  state (text-edit revert, reorder, re-add deleted, remove re-added) on the server.
- Added 4 restore-diff tests. Full `npm run check` green (52/52).

## 2026-07-01 — Phase 4: undo/redo history

- New `EditorSnapshot` (models) + `snapshot()`/`restore()` on `BookEditorStateService` capture
  the block mutation surface (blocks, deleted ids, order-dirty, selection). The block being
  edited is shallow-cloned in `snapshot()` so its in-place content typing can't corrupt a
  captured snapshot. Snapshots key off `uid`, so they survive autosave reconciliation.
- New `EditorHistoryService` (component-scoped): bounded (100) undo/redo stacks, `canUndo`/
  `canRedo` signals, `capture`/`undo`/`redo`/`reset`, with a `restoring` reentrancy guard.
- Two capture paths: (1) structural commands call `capture()` via the command service's
  `beforeMutation()` chokepoint; (2) text edits use an effect on edit-mode transitions —
  entering a block stashes a pending pre-edit snapshot, leaving commits it only if content
  changed (operation-level; native textarea undo handles per-keystroke).
- Wiring: `undo`/`redo` added as commands (Ctrl+Z / Ctrl+Y, also first in the toolbar);
  global Ctrl+Z/Ctrl+Y in the editor skip when a text field is focused (native undo wins);
  Enter-split calls `capture()` so a split is one undo step; `history.reset()` runs on
  replacement loads (initial + search-result navigation), preserved across pagination.
- Added `editor-history.service.spec.ts` (5 tests): undo/redo of a move, undo of a delete,
  redo-stack drop on new capture, reset. Updated command-service spec to provide history.
- Verified: full `npm run check` (format + lint + build + `test:ci` 48/48) green.

### Known limitations / follow-ups

- Sidebar block metadata edits (voice/lang/type) are not captured for undo (they aren't
  commands). Add capture if that becomes desired.
- Undo restoring an Enter-split leaves the source block in `edit` mode without refocusing the
  textarea — cosmetic; content/order restore correctly.
- Icons rely on the Google-hosted Material Icons font; offline shows ligature text.
- Reorder persistence assumes the loaded window; cross-window reordering is not supported.
- In-app E2E against a running backend still recommended before shipping.

## 2026-07-01 — Phase 3: bottom toolbar + command palette UI

- `command-icon.component.ts`: shared standalone icon, maps the semantic `EditorCommandIcon`
  to a Material Icons ligature (font already linked in index.html — avoids brittle inline SVG
  paths). Reused by toolbar + palette.
- `book-editor-toolbar.component.ts`: row of square icon buttons from
  `commands.toolbarCommands`, disabled via `isAvailable()`, plus a far-right button that opens
  the palette. Renders only the bar; the host decides visibility.
- `command-palette.component.ts`: plain fixed-overlay popup (matching the editor's existing
  search-modal pattern, not CDK overlay). Keyword search over all commands, arrow-key
  highlight, Enter to run, Esc/backdrop to close; auto-focuses + resets on open via an effect.
- Palette open-state lives on `BookEditorCommandService` (`paletteOpen`/`open`/`close`) so the
  toolbar trigger, palette, and global shortcuts share one source of truth.
- Wired into `book-editor.component`: toolbar host `@if (sidebarsOpen() && (isInSelectMode()
  || isInMassEditMode()))`, fixed bottom + inset `left-64/right-64` to clear the sidebars;
  `<app-command-palette />` always mounted (self-gates). Ctrl+K opens the palette; Escape now
  closes the palette first, ahead of search/selection/sidebars.
- Added `book-editor-command.service.spec.ts` (5 tests): run-gating, empty-clipboard paste
  no-op, copy→paste, cut, palette open/close.
- Verified: `format:check`, `lint`, `build`, `test:ci` (43/43) all green.
- **Note:** icons depend on the Google-hosted Material Icons font (already used by the app).
  Offline it degrades to ligature text; switch to inline SVG later if that becomes an issue.

## 2026-07-01 — Phase 2: command registry + new block operations

- New `EditorCommand` interface (`book-editor.commands.ts`) — data-only command definitions
  with reactive `isAvailable()`/`run()` closures and a semantic `icon` name (rendered later
  by a shared icon component). Drives both toolbar and palette.
- New `BookEditorCommandService` (component-scoped, added to editor providers): holds the
  in-app clipboard signal, builds the command list, exposes `commands` + ordered
  `toolbarCommands`, and a single `run(id)` chokepoint that gates on availability and calls
  `beforeMutation()` (Phase 4 will capture undo history there).
- Commands: move-up/down, edit, duplicate, copy, cut, paste, delete. Structural commands are
  unavailable while a block textarea is being edited.
- New immutable state methods on `BookEditorStateService`: `moveSelection(±1)` (works for
  contiguous + non-contiguous selections, keyed by uid, preserves selection),
  `duplicateSelection`, `pasteBlocks`, `deleteSelection`, `getSelectionPayloads`, plus
  selection helpers `selectionIndices`/`hasAnySelection`/`canMoveSelectionUp|Down` and
  `selectByIdentifiers`.
- **Order-dirty flag:** added `isBlockOrderDirtyState` folded into `isDirty` and reset on
  load/save. A pure reorder changes `new_order` but no per-block flag, so without it the
  autosave `isDirty` guard would silently skip persisting a move.
- Added `book-editor-state.service.spec.ts` (7 tests) covering uid assignment, move
  up/down/boundary, non-contiguous mass move, duplicate, and copy→paste.
- Verified: `format:check`, `lint`, `build`, `test:ci` (38/38) all green.

## 2026-07-01 — Phase 1: stable block uid + immutable mutations

- Added `uid?: string` to `ExtendedBlockDto` (`nikaudio-web/.../book-editor.models.ts`) — a
  stable client-side identity assigned once at ingest and preserved across the local_id→id
  save reconciliation.
- `BookEditorStateService`: added `generateUid()`/`ensureUid()`; assign uid in
  `setInitialVersion`/`appendBlocks`/`prependBlocks` and on the split tail block.
  `getBlockIdentifier` now returns `uid ?? local_id ?? id`.
- Converted the in-place block mutations to immutable (new block object + new array):
  `setSelectedBlock{VoiceId,LangId,Type}` (via new `updateSelectedBlock` helper),
  `setMassSelected*`/`updateMassSelectedBlocks`, `splitBlock`, and `deleteSelectedBlock`
  (splice → filter). `reconcileIds`/`applySuccessfulSave` already rebuild objects and now
  preserve `uid` via spread; removed the now-dead local_id→id selection refocus.
- Virtual-scroll `getBlockStringIdentifier` and the component `trackByBlockId` key off `uid`
  so height cache + DOM tracking stay stable across saves.
- **Deliberately left in place:** per-keystroke content editing still mutates
  `block.content` in `block.component.updateContent` (keeps caret behaviour + native undo).
  Phase 4 will make history safe for this by deep-copying only the edited block on capture.
- Verified: `format:check`, `lint`, `build`, and `test:ci` (31/31) all green.

## 2026-07-01 — Phase 0: devlog infrastructure

- Created `nikaudio-common/devlog/` with `DEVLOG.md` index and `doing/waiting/done/` folders.
- Added this feature file and documented the devlog convention in `nikaudio-common/AGENTS.md`.
- Next: Phase 1 — add `uid` and immutable block mutations in `nikaudio-web`.
