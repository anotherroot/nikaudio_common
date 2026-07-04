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

## 2026-07-04 — Signature redesign pass (home + books list)

- User disliked the flat token-only home ("miss the big colorful buttons"). New direction,
  kept as the design system to extend across pages: **Fraunces** display serif for headlines
  (`--font-display`, used with restraint via the `font-display` utility — see gotcha below),
  Inter for body/UI, and **three colorful gradient hues** — terracotta `#e2492a` (paste),
  teal `#0c8177` (upload), violet `#5a44d6` (catalog/accent) — as recurring accents with a
  soft tinted `box-shadow` and hover-lift (`translateY`).
- Home (`create-book`): colorful gradient action tiles (paste / upload / catalog) in the
  user-pinned layout (paste top-left, upload top-right, public-domain full-width below,
  browse link under). Upload + public-domain are **login-required** for guests: `.tile-locked`
  quiet variant + amber "Login required" badge. Guest home fits without a scrollbar. (A
  read-along karaoke strip was built as the signature but the user commented it out.)
- Books list (`books-list`): extended the same language. Fraunces "Your *library.*" headline,
  violet gradient "New book" pill (`.cta-accent`), and the page signature — each row is a
  **book-spine chip** whose gradient cycles the three hues deterministically
  (`book.id % 3` → `spine-paste/-upload/-catalog`) so the list reads like a shelf. Metadata
  moved to material-icons; whole row is the edit link with hover-lift; "no version" rows stay
  static. Skeleton + empty state restyled to match.
- **Tailwind v4 gotcha (saved as memory `tailwind-v4-theme-var-pruning`):** a new `@theme`
  var (e.g. `--font-display`) is pruned from `:root` unless a generated utility references it;
  referencing it only via `var()` in component SCSS silently falls back (serif → sans). Fix:
  put the `font-display` utility class on the element.
- Verified: prettier + eslint clean, `ng build` clean, light+dark screenshots of `/books`
  (authed via a session-cookie CDP shot — plain fe-shot hits the login redirect). Next pages
  to extend the language onto: TBD with user (auth screens, requests, settings).

## 2026-07-04 — Full app migrated to tokens; gradient era retired

- Every screen now uses the semantic tokens (parallel subagents restyled editor, player +
  requests, home + books list, auth/settings/misc; shell + shared UI done in-session).
  Grep-verified: zero `bg-gradient-to`/`hover:scale`/`active:scale` left in `app/`.
- Full redesigns: home/create (calm accent-medallion cards, amber "login required" chips,
  plain dialog), books list (accent-soft covers, "ID:" leak removed, header "New book"
  button), audio requests (pt-24 shell, tokenized cards/status chips), auth screens
  (single-border inputs, solid accent buttons), unreachable, settings (+ accent theme
  picker).
- Typography: Roboto → Inter 400–700 (fixes synthesized `font-bold`); removed dead
  `.btn-primary`.
- Audio requests DTO (`DtoTextRequestResponse`) exposes only id/hash/processed/type/created
  — no book/version name, so cards still say "Request #id". **Backend follow-up:** add
  version/book name (and failed state) to the list DTO.
- Purple stays only for mass-edit semantics; green = generate/success; red destructive;
  amber pending/draft. Editor keeps `transition-all` on blocks (animates edit-mode opacity
  fade — colors-only would snap it).
- Verified: lint, build, 102/102 tests, light+dark screenshots (home, login, player,
  public books). Remaining for later passes: icon-font → inline SVG consolidation,
  CDK Dialog migration for hand-rolled modals, editor sidebar UX rework, "Nikaudio" →
  Librofono rename in user-facing strings.

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
