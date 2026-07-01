# Book Editor Block-Index Autofetch

**Status:** done · **Area:** `nikaudio-web` (book editor)

## Goal

Change book editor autofetch from a scroll-height percentage trigger to a block-position trigger so
the next batch loads when the user reaches the last 50 loaded blocks.

## Decisions

- Use the CDK virtual-scroll `scrolledIndexChange` output as the trigger source.
- Treat the first visible loaded block as the scroll position.
- Trigger when `firstVisibleBlockIndex >= loadedBlocks.length - 50`.
- Reuse the existing `loadNextBlocks()` path so loading, total-count, and dirty-state guards stay
  centralized.

## Log

## 2026-07-01 — Completed

- Removed the old 80% scroll-height autofetch calculation from the book editor.
- Wired the virtual-scroll viewport index event to the component.
- Added tests for before-threshold, at-threshold, and already-fully-loaded cases.
- Verified with `nix develop -c npm test -- --watch=false --browsers=ChromeHeadless`,
  `nix develop -c npm run format:check`, and `nix develop -c npm run lint`.
