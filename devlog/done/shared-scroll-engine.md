# Shared virtual-scroll engine (book editor + audio player)

**Goal:** The book editor and audio player each had their own drifted copy of the
virtual-scroll strategy/directive/height-predictor. Unify the engine so behaviour (and the
end padding, prepend scroll-preservation) is shared instead of duplicated.

## Decisions

- Share the **engine only** (strategy + directive wiring + gutter styles); keep the two block
  components separate (editor = full editor, player = read-only viewer).
- The audio player's copy was an older fork; the editor's was the more complete one, so the
  generic strategy is a port of the editor's (prepend preservation, bottom scroll gutter,
  total-size throttle).

## Implementation

- New generic `shared/block-scroll/BlockVirtualScrollStrategy<T>` parameterized by an id
  accessor and the rendered component's DOM node name; both feature directives construct it.
- Deleted the drifted audio strategy + both `return 50` height predictors.
- Player gained the editor's top+bottom end padding for free; its load-more trigger stays the
  pixel-ratio scroll handler (not the editor's block-index threshold) because it paginates in
  small batches. Shared scroll SCSS moved to global `styles.scss` (`--block-scroll-gutter`).

## Verification

- `ng build`, `ng lint`, `prettier --check`, 84 unit tests pass (gutter test updated for the
  renamed class). Headless smoke confirmed the player virtualizes, shows top+bottom padding,
  and autofetches sequentially without runaway.

## 2026-07-02 — Committed (`afc6b0a`)
