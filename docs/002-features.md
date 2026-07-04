# 002 — Features

What the product does today, grouped by area. Planned-but-unbuilt work lives in
[006-roadmap.md](006-roadmap.md).

## Books & editing

- **Create a book** from pasted text, a text file, or an EPUB. The backend parses input
  into ordered blocks (paragraphs + chapter titles).
- **Block editor** (`/book/:id`): virtual-scrolled block list with batch autofetch,
  edit/split/merge/move/add/delete/duplicate, system clipboard copy/cut/paste, a
  mode-aware bottom toolbar with disabled-command reasons, a searchable **command
  palette**, frontend-only undo/redo, in-book search, Markdown export (whole book or
  selection), and an unsaved-changes navigation guard.
- **Versions**: a book has multiple `BookVersion`s; versions can be branched, renamed,
  deleted, and marked readonly. Block order is per-version.
- **Voice & language** selectable per version and overridable per block.
- **Pronunciations**: per-version and per-block pronunciation entries (term →
  Misaki/IPA-style phonemes), a row-level pronunciation builder, and a Misaki English
  phoneme reference panel.
- **Disable block**: a block stays in the book and the audiobook timeline but is skipped
  during audio generation (rendered as a zero-length silent block).

## Audio generation & playback

- **Queue a version** (or a selection of blocks as a **sample**) for audio. Queueing
  snapshots block content immutably; later edits don't affect queued jobs.
- **Queue status / audio requests** views (`/audio-requests`), request deletion, and
  "view source blocks" for a request.
- **Audio player** (`/audio-player/:id`): chunked audio loading, floating transport bar,
  click-to-seek on text, ±10s and ±paragraph skips, current-block highlight with progress
  fill, and auto-scroll that follows playback across paginated text.
- **Create a book from an audiobook**: rebuilds an editable book from the exact snapshots
  an audiobook was generated from.

## Public-domain catalog

- **Browse** (`/public-books`): cover grid with debounced search; detail page per book
  with a first-chapter text sample and its shared audio versions.
- **Admin curation** (`/admin/public-books`, `User.Role == "admin"`): create catalog
  entries (title/author/origin/cover + text or file), draft/publish lifecycle, metadata
  edit, and a user-**suggestion** inbox ("couldn't find your book?").
- **Make your version**: clone a catalog book into your own **public book** — text is
  locked (immutable, no reorder/add/delete, no branching), but headings, voice, language,
  pronunciations, and disable-block remain editable.
- **Shared audio versions + voting**: audio generated from a public clone is listed on the
  catalog book's page, ranked by net like/dislike score (logged-in users vote).
- **Make private** (one-way): flips a public clone to private, unlocks its text, and drops
  its audio from the catalog.

## Accounts & access

- Register / email confirmation / login / logout / forgot + reset password. Cookie-based
  sessions (DB-backed, opaque).
- **Guest books**: create and edit a book without an account via a guest token, with
  expiry.
- User settings (`/settings`).
- Admin role gates the catalog admin section (backend middleware + role-guarded routes).

## Worker & pipeline

- Workers register with a shared auth token, then authenticate per-request with a bearer
  token; heartbeat via status updates.
- Job claiming is atomic (`FOR UPDATE SKIP LOCKED`) with `locked_at` for crash recovery.
- Workers receive block **snapshots**, generate audio with Kokoro (ONNX), and upload an
  `.m4b` plus per-block end timestamps and phoneme ("foname") content.
- A `dummy_worker` test client exists in the backend repo for pipeline testing.

## Landing page

- Static one-page Librofono site in `nikaudio-landing` (SEO meta, sitemap, robots), with
  its own `deploy_landing.sh` and nginx config example. Domain registration and first
  deploy are pending.

## Known not-yet-implemented (registered but stubbed)

- `POST /queue/block/:block_id` (single-block audio queueing) returns 501.
- `GET /worker/file/:audio_id` (worker file download) returns 501.
- The worker repo's `worker.py` is still a local file-oriented script, not the
  backend-polling daemon (see [006-roadmap.md](006-roadmap.md)).
