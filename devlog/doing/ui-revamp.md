# UI Revamp + Dark Mode

**Status:** doing · **Area:** `nikaudio-web`

## Goal

Make the whole frontend look and feel modern, slick, and simple, working as one coherent
design — and add dark mode. Spread the newer design language (book editor / audio player /
public books: flat surfaces, subtle borders, rounded-2xl, floating glass pills) across the
app and retire the older gradient-heavy style (home/create, books list, auth screens).

## Decisions

- **Tokens first, dark mode via tokens.** Define semantic color tokens (surface,
  surface-raised, ink, ink-muted, line, accent…) in Tailwind 4 `@theme`, redefined under a
  `.dark` class, instead of sprinkling `dark:` variants across ~25 templates. Templates use
  `bg-surface text-ink border-line`; dark mode becomes nearly free and consistency is
  enforced.
- **One accent color.** Today blue (header/editor), indigo (player), purple (samples/mass
  edit), green (sample buttons) compete. Consolidate on a single brand accent (leaning
  indigo; final call pending), purple stays as the mass-edit semantic, green/red reserved
  for success/danger.
- **Kill the icon font, standardize inline SVG icons** (pattern: editor's
  `command-icon.component.ts`). `index.html` also has a duplicate Material Icons `<link>`
  with `src=` instead of `href=` — fix while at it.
- **Typography:** Roboto is loaded at 300/400/500 but `font-bold` (700) is used everywhere →
  synthesized bold. Switch to Inter (or system stack) with real weights; maybe a serif for
  reading surfaces.
- **Planned order:** 1) tokens + ThemeService (localStorage + prefers-color-scheme, toggle in
  Settings→Appearance) 2) shell (header/menus/layout/toast) 3) editor + player token swap +
  sidebar polish 4) public books 5) redesign of dated screens (home/create, books list,
  auth, requests, settings) + CDK Dialog migration + `@if/@for` modernization as touched.
- Backend `ownerLabel` (`Reader #<user_id>`, publicbooks/audio_versions.go) leaks sequential
  user IDs; later show "You" for own versions / stable pseudonyms.

## Log

## 2026-07-04 — Dark mode foundation shipped

- Semantic tokens (`--color-surface/-raised`, `ink/-muted/-faint`, `line/-strong`,
  `accent/-strong/-soft/-ink`) in Tailwind 4 `@theme`; **accent = indigo**. New/revamped
  templates should use `bg-surface`, `text-ink`, `border-line`, `bg-accent`, ....
- **Transitional dark strategy:** besides the semantic tokens, `.dark` remaps the raw palette
  variables (white, gray scale, hue -50/-100/-200 tints, -600/-700/-800 text shades) so every
  legacy template goes dark immediately without edits. Tailwind 4 compiles utilities to
  `var(--color-*)`, which makes this possible. The remap block in `styles.scss` shrinks as
  screens migrate to semantic tokens, then gets deleted.
- `ThemeService` (`core/theme/`): light/dark/system preference, localStorage key
  `nikaudio-theme`, matchMedia tracking, toggles `.dark` on `<html>`. Pre-boot script in
  `index.html` prevents the light flash (keep its key in sync). Sun/moon quick toggle in the
  header (desktop nav + mobile menu); full Light/Dark/System picker in Settings → Appearance.
- Fixed the duplicate Material Icons `<link src=...>` bug in index.html.
- Verified: lint, build, 102/102 tests, dark screenshots of public books, login, audio
  player (player looks great; gradient-era screens degrade acceptably until their redesign).
- Screenshot harness: `shot.mjs` (session scratchpad) — headless chromium + CDP,
  emulates `prefers-color-scheme` for dark shots.

## 2026-07-04 — Review + first public-books polish

- Reviewed every screen with the user. Verdict: editor/player/public-books language is the
  keeper; home/create, books list, auth screens, unreachable are dated (gradient
  backgrounds, gradient buttons, hover:scale) and get full redesigns; audio-requests is
  content-poor ("Request #14") and should become a proper library view later.
- Public books (user feedback with screenshots):
  - Content now starts below the floating header (`pt-24`) on list + detail — the
    "Couldn't find your book?" button was colliding with the nav pill.
  - Removed the Sample section from the detail page (user request).
  - Slicker audio-version rows: circular accent play button left, owner + duration middle,
    horizontal vote pill (👍 score 👎) right, replacing the vertical thumb stack + "Listen"
    link.
  - Durations under 1 min now show seconds ("17s" instead of "0m").
- Verified via ng lint + build and headless-chromium screenshots against the dev server.
  Note: screenshots must load `localhost:3031`, not `127.0.0.1:3031` (CORS origin mismatch
  sends the app to /unreachable).
