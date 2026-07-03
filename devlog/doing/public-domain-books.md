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
