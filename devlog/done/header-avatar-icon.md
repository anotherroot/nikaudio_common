# Header Avatar Icon

**Status:** done · **Area:** `nikaudio-web` (shared header)

## Goal

Replace the placeholder `U` inside the authenticated header profile circle with a real avatar icon.

## Decisions

- Keep the existing circle size, gradient background, and menu trigger behavior unchanged.
- Use an inline SVG avatar glyph inside the existing badge to avoid adding new dependencies or
  changing layout metrics.
- Add a focused component test in the logged-in state so the placeholder letter does not return.

## Log

## 2026-07-01 — Completed

- Replaced the hardcoded `U` with an avatar SVG in the desktop profile trigger.
- Added a user-header component test that checks for the icon and absence of the placeholder text.
- Verified with `nix develop -c npm test -- --watch=false --browsers=ChromeHeadless`,
  `nix develop -c npm run format:check`, and `nix develop -c npm run lint`.
