# 004 — Data model

GORM models live in `nikaudio-be/src/models`; the runtime schema comes from committed SQL
migrations (`src/db/migrations/postgres`), not `AutoMigrate`. PostgreSQL is the runtime
DB; SQLite exists only for throwaway unit tests.

## Entity map

```
User ─┬─▶ Session (opaque cookie sessions)
      ├─▶ Book ──▶ BookVersion ──▶ Block
      │     │           │ BlockOrder JSON = authoritative order
      │     │           └ Pronunciations (JSONB)
      │     └ Visibility / GuestToken / SourcePublicBookID
      ├─▶ AudioRequest ─┬─▶ BlockSnapshot (immutable copies, ordered)
      │       │         └─▶ Queue (waiting → processing → done)
      │       └ PublicBookID (set for catalog clones)
      └─▶ AudioVersionVote

Worker ──▶ Queue.WorkerID (claimed jobs)

AudioRequest ──▶ AudioBook ──▶ AudioBlock ──▶ BlockSnapshot (SET NULL)

PublicBook ──▶ canonical Book + BookVersion (system-owned)
BookSuggestion (user catalog requests)
Voice / Lang (static lookups, referenced from version/block/snapshot/request)
```

## Authoring side

### `Book`
- `UserId *uint` — nil means **guest book** (`GuestToken` + `GuestExpiresAt` set).
- `HashID` — public identifier (unique).
- `Visibility` — `private` | `guest` | `public` (see access rules below).
- `SourcePublicBookID *uint` — set when cloned from the catalog; retained for attribution
  even after make-private. `Book.IsPublic()` ≡ `Visibility == public && SourcePublicBookID != nil`
  and marks a **text-locked public book**.
- Cascade-deletes its `Versions` and `Blocks`.

### `BookVersion`
- `ParentVersionID` — branching lineage.
- **`BlockOrder`** — JSON array of block IDs (`"[1, 4, 2, 3]"`). This is the authoritative
  block order, **not** DB row order. Parse it only via `src/bookblocks`.
- `IsReadonly` — all-or-nothing lock (distinct from the *partial* public text-lock).
- `Pronunciations` (JSONB list of `{term, pronunciation, source}`), `VoiceID`, `LangID`.

### `Block`
- `Type` — `"paragraph"` or `"chapter_title"`.
- `Disabled` — kept in the book/audiobook but skipped at generation.
- Per-block `Pronunciations` + `UseBookPronunciations`, optional `VoiceID`/`LangID`
  overrides.

## Generation side (immutable once queued)

### `AudioRequest`
- `HashID` public id; `RequestType` `"book"` or `"block"`; `Processed` flag.
- `PublicBookID *uint` — set when the source is a public catalog clone → the result
  becomes a shared audio version on that catalog page.
- Owns the `BlockSnapshots`.

### `BlockSnapshot`
- Immutable copy of a block at queue time: `Content`, `Type`, `Disabled`,
  `EffectivePronunciations`, voice/lang, plus `BlockID` (provenance) and
  **`OrderIndex`** — authoritative order for this request.
- Worker payloads are always built from snapshots; editing a book after queueing must not
  change what a queued worker processes.

### `Queue`
- One row per `AudioRequest` (`uniqueIndex`). `Status`: `waiting` → `processing` → `done`.
- `WorkerID` + `LockedAt` — claim bookkeeping; stale `locked_at` enables crash recovery.
  Claiming uses `FOR UPDATE SKIP LOCKED`.
- `Type`: `"registered"` or `"unregistered"` (queue priority classes).

### `Worker`
- `TokenHash` (bearer token, hashed), `WorkerType` (`"free"`/`"registered"`),
  `LastSeenAt` heartbeat.

## Result side

### `AudioBook`
- One per processed request: `FilePath` (filestore), `LengthMS`, effective
  `Pronunciations`, owner `UserID`.

### `AudioBlock`
- Per-block playback metadata: `StartMs`/`EndMs`, phoneme content (`FonameContent`),
  `Pronunciations`.
- **`BlockSnapshotID`** (SET NULL on snapshot delete) — the link that lets future
  block-level patching find the exact source text of any audio span.
- `Disabled` — present in the timeline but zero-length/silent (synthesized by the backend
  for disabled snapshots so player text and timing stay complete).

## Public-domain catalog

### `PublicBook`
- Catalog entry: `HashID` (URL slug), `Title`, `Author`, `Description`, `CoverPath`
  (filestore), `OriginURL`/`OriginName` (e.g. Project Gutenberg).
- `Status` `draft` | `published` (+ `PublishedAt`); drafts visible to admins only.
- `CanonicalBookID`/`CanonicalVersionID` — the master text is a **system-owned
  Book/BookVersion**, reusing all block/order/snapshot/branch machinery for samples and
  cloning.

### `BookSuggestion`
- User-submitted "couldn't find your book": `Title`, `Link`, `Note`,
  `Status` `new` | `reviewed` | `added`.

### `AudioVersionVote`
- One row per (user, audiobook), `Value` +1/-1; hard-deleted when a vote is cleared.
  Shared audio versions are ranked by net score.

## Users & lookups

- `User` — email/password auth, `IsConfirmed` + confirm/reset tokens,
  `Role` `"user"` | `"admin"`.
- `Voice`, `Lang` — static lookup tables (`NameKey`), referenced from versions, blocks,
  snapshots, and requests.
- `PronunciationList` — a JSONB-backed `[]{term, pronunciation, source}` value type used
  on versions, blocks, snapshots, and audiobooks.

## Access rules

- **Owned books** require owner auth; **guest books** require the guest token (until
  expiry); **published catalog content** is readable by anyone.
- Public book (catalog clone) = *partial* lock: text/order/add/delete immutable
  (409 `ErrTextLocked`), branching rejected — but headings, voice, lang, pronunciations,
  and disable-block stay editable. Distinct from `BookVersion.IsReadonly`.
- Make-private is **one-way**: visibility → private, text unlocks, audio drops from the
  catalog; `SourcePublicBookID` is kept for attribution.

## Invariants (do not break)

1. `BookVersion.BlockOrder` is the authoritative order for live editing;
   `BlockSnapshot.OrderIndex` is authoritative once queued.
2. Worker payloads come from `BlockSnapshot`s only — post-queue edits never leak into a
   queued job.
3. New `AudioBlock` rows must link `BlockSnapshotID` (patching depends on it).
4. Disabled blocks are excluded from worker payloads but represented as zero-length
   `AudioBlock`s so timelines stay complete.
5. Privacy boundaries above hold across every feature.
