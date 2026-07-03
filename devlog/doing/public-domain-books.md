# Public Domain Books

Goal: build Nikaudio's public-domain audiobook repository — an admin-curated catalog users can
browse, clone into their own "public book" (text-locked, but headings/voice/lang/pronunciations/
block-disabling editable), generate shared audio versions, and rank by community like/dislike.
Also adds a general disable-block feature and create-book-from-audiobook.

Decisions:

- Catalog master text is stored in full as a system-owned `Book`+`BookVersion`, reusing the
  existing block/order/snapshot/branch machinery. A new `PublicBook` model holds catalog metadata
  (title, author, cover, origin link, draft/published status) + canonical version reference.
- Admin is in-app (reuse `User.Role == "admin"` + a `RequireAdmin` middleware and a role-guarded
  Angular section), not a separate app. Drafts are visible to admins before publish.
- Covers uploaded via the existing filestore abstraction. Only logged-in users vote; versions
  ranked by net score (likes − dislikes).
- Public book = `Book.Visibility == public` AND `SourcePublicBookID != nil`. It's a *partial* lock
  (text immutable) distinct from the all-or-nothing `BookVersion.IsReadonly`.
- Disable-block: block stays in the audiobook but is skipped at generation. Snapshotted with a
  `disabled` flag; excluded from the worker payload (no worker change); backend synthesizes
  zero-length disabled `AudioBlock`s so the player timeline/text stay complete.
- Make-private is one-way (no reverse endpoint): flips visibility to private, unlocks text, drops
  the book's audio from the catalog.

Planned phases: B0 models/migrations · B1+F1 disable-blocks · B2+F6 admin ingest+UI ·
F2 browse/suggest · B3+B5+F4 make-your-version/text-lock/make-private · B4+F3 versions+voting ·
B6+F5 create-book-from-audiobook.

## 2026-07-03 — Create book from audiobook (B6/F5)

- **B6 (backend)**: `POST /result/:hash_id/to-book` (RequireUser) builds a new book from the request's
  ordered `BlockSnapshot`s via new `books.CreateBookFromBlocksContext` (content/type/disabled/
  pronunciations/voice/lang). A public-domain audiobook (`AudioRequest.PublicBookID != nil`) yields a
  text-locked public book with `SourcePublicBookID`; anything else yields a private editable book.
  Access reuses `CanReadBook` (public → anyone, private → owner).
- **F5 (frontend)**: `AudioPlayerService.createBookFromAudio()` + a "Create a book from this" button in
  the audio player's Audio Actions sidebar (logged-in only), navigating to the new book's editor.

Tests: public-vs-private book-from-blocks service test. Full `go test`, `make swagger-check` (in sync),
FE build/lint, and 102 FE specs green. **All planned phases (B0–B6, F1–F6) are now implemented.**
Remaining before moving to done: a manual end-to-end pass with the running stack (admin ingest → publish →
browse → make-your-version → generate with a disabled block → vote → create-from-audiobook → make-private).

## 2026-07-03 — Text-locked public editor + make-private (B5/F4)

- **B5 (backend enforcement)**: `UpdateBookContext` takes `TextLocked` (derived from `Book.IsPublic()`
  in the handler mapping) — it ignores content edits, drops reordering, and rejects add/delete with
  `ErrTextLocked` (409). `BranchBookVersion` returns 409 for public books. New
  `POST /book/:book_id/make-private` → `MakeBookPrivateContext` flips visibility to private (one-way;
  audio drops from the catalog, text unlocks). `is_public` added to `BookVersionResponse`.
- **F4 (editor public mode)**: editor state exposes `isPublicLocked` / `isTextLocked`; all
  text/structure mutations (edit/split/merge/move/add/delete/paste/duplicate) now gate on `isTextLocked`
  while heading/voice/lang/pronunciation/disable stay on `isReadonly`. Command availability + reasons
  updated; the block textarea is read-only in public mode; the Versions panel is hidden; a "Public book"
  info panel + "Make private" button with a consequences confirm dialog were added.

Tests: text-lock update test (content ignored, heading/disable applied, add-block rejected) + contract
key update. Full `go test`, FE build/lint, and 102 FE specs green. Remaining: B6/F5
create-book-from-audiobook.

## 2026-07-03 — Catalog end-to-end (B2/F6/F2 + B3 + B4/F3)

Built the public-domain catalog through to a working detail page:

- **B2 (backend ingest + reads)**: `publicbooks` service (create canonical system-owned book/version,
  list with search + draft visibility, detail + first-chapter sample, publish/unpublish, metadata edit),
  `RequireAdmin` middleware, filestore `CoverStore` (covers under `./storage/covers`), and the
  `public_book.go` handler + routes (`/public-books`, `/public-books/:slug`, `/cover`, admin CRUD,
  `/public-books/suggest`, `/admin/suggestions`). Auth check now returns `is_admin`.
- **B3 (make-your-version)**: implemented the old 501 `CreateBookFromPublicBook` — clones the canonical
  version into a user-owned Book (`Visibility=public`, `SourcePublicBookID`), reusing the branch clone
  shape. Admins can clone drafts.
- **B4 (versions + voting)**: `AudioRequest.PublicBookID` is set when queuing a public clone;
  `ListAudioVersions` ranks processed audiobooks of still-public clones by net score;
  `POST /public-books/audio/:id/vote` upserts/clears a vote and returns the new score.
- **F6 admin UI**: `/admin/public-books` (role-guarded) — catalog list incl. drafts, create dialog
  (title/author/origin/cover/text|file), publish toggles, suggestions list.
- **F2 browse + suggest**: `/public-books` cover grid + debounced search + "Couldn't find your book?"
  dialog (explains public domain + trusted sources) → suggestion submit. Nav entries added
  (Public Books for all; Catalog for admins).
- **F3 detail**: `/public-books/:slug` — cover, sample, origin link, "Make your version", and the ranked
  audio-versions list with optimistic like/dislike.

Client regenerated with `nix develop --command npm run generate-api` (works in the flake shell — updated
the memory). Focused tests: publicbooks create/list/publish/sample/suggestion + clone + vote/list +
made-private hiding. Full `go test ./...`, FE build/lint, and 102 FE specs green. Still to do: text-locked
public-book editor mode (F4) + make-private (B5), and create-book-from-audiobook (B6/F5).

## 2026-07-03 — B0 models/migrations + B1/F1 disable-blocks

Shipped the first slice on `feature/public-domain-books`:

- **B0**: migration `000005_public_domain_books` (public_books, book_suggestions, audio_version_votes
  tables; `disabled` on blocks/block_snapshots/audio_blocks; `source_public_book_id` on books;
  `public_book_id` on audio_requests) + GORM models + domain constants. Verified via the isolated-schema
  Postgres migration integration test (extended its assertions).
- **B1 (backend disable-blocks)**: `disabled` threaded through `UpdatedBlock` DTO → update service →
  `GetBookVersion`; snapshotted in `book_audio.go`; **excluded from the worker payload** in
  `workerjobs/claim.go` (no worker change needed); result assembly in `audioresults/worker_audio.go`
  now synthesizes zero-length `Disabled` AudioBlocks in reading order, with `start_ms, id` tiebreakers
  in `result.go`/`audioqueries` so paging stays aligned. Focused tests added for both the worker-payload
  exclusion and the disabled-block synthesis. Contract test key lists updated.
- **F1 (editor + player)**: `disabled` on the editor block model/payload, `toggleBlockDisabled` /
  `toggleSelectionDisabled` state commands, a `toggle-disabled` toolbar/palette command ("Skip in audio",
  block icon), and dimmed + line-through "Skipped" styling in both the editor block and audio-player block.
  State-service and command-service specs updated/added.

Note: the offline sandbox has no Java/network, so `openapi-generator-cli` can't run. Added `disabled?` to
the three affected generated client models by hand (matching generator output); a real `npm run generate-api`
should be run when convenient to confirm no drift. Backend `go test ./...` and FE build/lint/`ng test`
(102 specs) all green.

## 2026-07-03 — Feature kickoff

Explored the codebase and wrote the implementation plan. Committed pre-existing in-flight
pronunciation/audio work on `nikaudio-be` master as a checkpoint, then branched
`feature/public-domain-books` so this feature stays isolated. Starting with B0 (migrations + models).
