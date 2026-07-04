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

## 2026-07-04 — Settings redesigned; Subscription + Billing removed

- **Removed the Subscription and Billing tabs** (user request) — both were "coming soon"
  placeholders with no backing feature. Dropped the dead `activeTab !== 'personal' &&
  !== 'appearance'` fallback too; `activeTab` is now typed `'personal' | 'appearance'`.
- Redesigned in the shelf language: a page-level Fraunces "Settings" headline + subtitle
  above the panel; the two tabs became `.ed-row`s (violet `.ed-row-active` when selected);
  section headings are Fraunces `.ed-title`; the email field label is an `.ed-label` (violet
  tick); Save is a book-hue `.ed-cta`. The page roots on `.hue-violet` (the brand accent,
  since settings isn't tied to a book). Layout moved from a vertically-centred card to the
  top-aligned `pt-24` shell the other pages use. Theme picker unchanged.
- Copy: "Personal Data" → "Personal data", "Save Changes" → "Save changes".
- Verified: eslint + prettier + build clean, settings unit test passes, authed light+dark
  screenshots (Personal tab). Appearance tab not re-shot — the synthetic tab-click doesn't
  register under zoneless CD — but it's the pre-existing theme picker with only
  `.ed-title`/`.ed-label` swapped in, both proven on the Personal shot.

## 2026-07-04 — Public catalog (list + detail) redesigned in the shelf language

- Brought the two user-facing public-books screens into the language. They're a **catalog**
  (browsing many books), so they use the full-scale shelf primitives (`.display-title`,
  `.cta-accent`, `.shelf-row`/`.shelf-chip`, `.hue-*`) rather than the compact reader chrome —
  the same split as home / My Books / My Audio.
- **Per-book identity by slug.** `hueForSlug(slug)` (in `public-books.service.ts`, a char-sum
  mod 3) picks a shelf hue deterministically, so a book keeps one colour from its cover in the
  grid through to its detail page — the card/detail DTOs share only `slug`, so that's the key.
- **List:** Fraunces "The public *library.*" headline; `Suggest a book` outline button;
  loading skeletons; a friendlier empty state. The signature is the **cover grid** — a book
  with no cover art becomes a coloured gradient spine (`.gradient-hue`) with a "Public domain"
  eyebrow + Fraunces title, and every card lifts on hover in its own hue (`.book-cover`, new
  in `styles.scss`). Real covers still render as images.
- **Detail:** root carries the book hue; gradient spine fallback; Fraunces title; the primary
  **Make your version** action reuses the book-hue `.ed-cta` (the one bold action, themed to
  the book); Fraunces "Audio versions" with version rows as `.shelf-row`s (gradient play
  `.shelf-chip` → player, owner + duration, the vote pill kept). Fixed a token bug: the vote
  buttons' `hover:bg-gray-100` → `hover:bg-ink/5` (was invisible/ wrong in dark).
- Copy: "Public-Domain Books" → "The public library"; "Couldn't find your book?" → "Suggest a
  book"; "Back to catalog" → "Back to the library".
- Verified: eslint + prettier + `ng build` clean; light+dark screenshots of both pages
  (guest-viewable — Dracula, no cover, renders the teal gradient spine and carries that hue
  into the detail page and its `.ed-cta`). No public-books unit tests exist to update; the
  version-row styling reuses the already-proven My Audio `.shelf-*`.

## 2026-07-04 — Audio player redesigned in the shelf language (+ primitives promoted to global)

- Extended the same language into the **audio player**, mirroring the editor: floating
  Fraunces title pill + gradient headphones chip, two hue-tinted card sidebars, calm reading
  column left untouched, transport pinned bottom.
- **Per-book identity, same key as the editor.** `bookHue()` is keyed by `book_id % 3` — the
  result DTO already carries `book_id`, so a book keeps one colour across My Books → editor →
  player. Added `bookId` + a `generatedLabel` (friendly `processed_at`) to
  `audio-player.service.ts`; the hue class rides on `<page-layout [class]="bookHue()">` so the
  cascade reaches the fixed transport too (custom-prop inheritance follows the DOM tree, not
  layout).
- **Signature = the transport.** The one thing a player has that the editor doesn't, so it
  wears the book's hue most boldly: play button + progress fill are the book gradient
  (`.transport-play/-fill/-thumb`) instead of flat indigo. Left panel: live `Now playing` +
  `Progress` cards (the progress card's mini-bar reuses `.transport-fill`, tying it to the
  transport). Right panel: a `Details` card (type / length / blocks / generated) in scroll,
  with **Download audiobook** (bold book-hue `.ed-cta`) over **Create a book** (quiet
  `.ed-cta-quiet`) pinned in a bordered footer — same footer pattern as the editor.
- **Primitives promoted to global (one source of truth).** The `.ed-*` reader-chrome set was
  trapped in the editor's *component-scoped* SCSS, so the player couldn't reuse it (view
  encapsulation). Moved `.ed-card/-label/-chip/-title/-row/-cta/-cta-sample` + new
  `.ed-cta-quiet` + `.transport-*` into `styles.scss` under "Reader chrome"; editor SCSS now
  only holds `textarea { font-family: inherit }`. Corrects the earlier note below that placed
  these in component SCSS. No editor regression: rule bodies are byte-identical and no `.ed-*`
  element carries a conflicting Tailwind utility (audited — only `.ed-title` overlaps, with
  `rounded/px/py`, which `.ed-title` never sets), so the specificity drop is inert.
- Verified: build + eslint + prettier clean, 84/84 audio + editor tests pass (updated the
  player spec's copy assertions: `Audiobook Info`/`Audio Actions` → `Now playing`/`Details`,
  and the toggle titles → `Open/Hide panels`). Light+dark player screenshots via a **public**
  guest-viewable audiobook (`/result` serves public-book audio without owner auth) — no DB
  mutation or credential-guessing needed; the editor stays behind its auth guard so it was
  verified by the audit above rather than a shot.

## 2026-07-04 — Editor button refinements (user feedback)

- Removed the right-panel titles (`Book/Block/Mass actions`). Pinned each primary generate
  button into a bordered footer at the bottom of the right panel; **Generate sample** became a
  green `.ed-cta-sample` twin of the book-hue **Generate audiobook** so a sample always reads
  as distinct. Removed the redundant **Delete block** + **Deselect** buttons in block mode
  (delete still lives on the bottom command toolbar; re-clicking deselects). Calmed the loud
  accent-soft pill buttons (Create / Save / Apply) to neutral outline. Commit `73d374a`.

## 2026-07-04 — Book editor redesigned in the shelf language

- Extended the My Books / My Audio language into the editor **chrome** while keeping the
  block-editing column deliberately calm (a working surface shouldn't compete with its
  chrome). User picked the "full panel restyle" scope over minimal/CTA-only.
- **Per-book identity:** the editor root carries the book's own shelf hue (`bookHue()`,
  keyed by `book_id % 3` — the same colour as its spine in My Books). Everything compact
  reads `--grad-a/-b/--tint` from that one source, so a book is one consistent colour end to
  end: title spine chip, section ticks, row hovers, and the primary CTA. Verified violet
  (Two Cities) vs coral (Pride & Prejudice) render their own hue.
- **Panels → cards.** Both sidebars, in every mode (book info/actions, block info/actions,
  mass edit), became soft `.ed-card`s led by hue-ticked `.ed-label`s (tick via
  `::before`, so labels are consistent and tick-free in markup). Overview gained a Fraunces
  stat row (blocks/words/chars); versions, audiobooks and samples read as compact shelf rows
  (`.ed-row`, active row hue-tinted). Book title is Fraunces (`.ed-title`) + gradient spine
  chip in both the floating pill and the sidebar header.
- **CTA:** "Submit Entire Book" → **"Generate audiobook"**, restyled to the book-hue gradient
  (`.ed-cta`) with a graphic_eq icon — the one bold action. "Generate Sample" → "Generate
  sample", keeps the green sample semantic. Modal headings picked up Fraunces.
- Editor-scoped compact primitives (`.ed-card/-label/-chip/-title/-row/-cta`) live in the
  component SCSS — a legitimately denser context than the full-width `.shelf-*`; colour still
  comes from the shared `.hue-*` source, not redeclared. Functional colours left alone
  (accent = selection ring, purple = mass edit, red = destructive).
- Verified: 45/45 editor tests pass, lint + prettier + build clean, authed light/dark +
  select-mode screenshots (via the cookie-injecting CDP harness; dev book 36 given a heading
  + paragraphs so the surface is realistic). Note: the api `/book/version/:id` read route
  populates its actor via `ResolveActor` (in-memory session store), so a session created in a
  prior BE process 403s after an `air` restart — re-login for a fresh cookie.

## 2026-07-04 — Design-system primitives consolidated (one source of truth)

- Resolved the duplication flagged below: the shelf visual language now lives once, as
  global classes in `styles.scss` — `.hue-coral/-teal/-violet` (the three brand hues as
  `--grad-a/-b/--tint`), `.display-title` (+`em`), `.cta-accent`, and
  `.shelf-row`/`.shelf-chip`/`.shelf-chip-quiet`/`.shelf-arrow` (the list row pattern).
- Home tiles, books list, and my-audio consume them. Components keep only genuinely local
  styles: home's `.tile*` structure + read-along, the books-list skeleton shimmer, and
  my-audio's `.status-*` pills + `.audio-spinner`. Home hero keeps its tighter leading via a
  `leading-[1.03]` utility on the `.display-title` element.
- New pages get the language for free: add `.shelf-row` + a `.hue-*` + `.shelf-chip`.
- No visual change — verified home/books/my-audio render identically (light+dark), lint +
  build clean.

## 2026-07-04 — "Requests" → "My Audio", redesigned in the shelf language

- Renamed the user-facing "Requests" nav item + page to **My Audio** (user's call; "Requests"
  described it from the system's side). Route path kept as `/audio-requests` to avoid breaking
  links; only labels + `title` changed.
- Redesigned `audio-requests` in the same language as home / books list: Fraunces "Your
  *audio.*" headline, rows with the shelf hue-cycling chip (`book.id % 3`). **Ready** items get
  a colourful gradient play-chip and the whole row is an anchor to the player (hover-lift +
  arrow); **Generating** items get a quiet muted chip + amber pill + spinner and aren't
  clickable. Status copy Completed/Processing → **Ready/Generating**; each row now leads with
  what it is ("Audiobook #id" / "Sample #id") since the DTO still has no book name.
- Removed the dev-only `hash_id` mono display and the old inline SVGs (now material icons).
  Dropped the now-unused `Router`/`onRequestClick`/`getStatusClass`/`getRequestTypeLabel`.
- **Duplication watch:** the tile/chip/hue primitives now live in three component SCSS files
  (create-book, books-list, audio-requests). Next design-system touch should promote the hue
  set + card/chip to shared global classes (or `@theme` tokens) — one source of truth.
- Verified: prettier + eslint clean, `ng build` clean, light+dark authed screenshots of
  `/audio-requests` (ready book + ready sample + generating, via temporary DB rows since the
  dev account had no audio; rows deleted after).

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
