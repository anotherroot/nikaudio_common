# 003 — Architecture

## Workspace layout

The workspace root (`~/Projects/nikaudio`) is **not** a git repository; it contains five
sibling repos:

| Repo | Role | Stack |
| --- | --- | --- |
| `nikaudio-web` | Frontend SPA | Angular 20, TS 5.9, Tailwind 4, zoneless CD, generated OpenAPI client |
| `nikaudio-be` | API / backend | Go, Gin, GORM + PostgreSQL, golang-migrate, swaggo |
| `nikaudio-worker` | TTS worker | Python 3.12, kokoro-onnx, misaki (G2P), onnxruntime(-gpu), ffmpeg, espeak-ng |
| `nikaudio-landing` | Public landing site | Static HTML/CSS/JS one-pager |
| `nikaudio-common` | Deploy/config + cross-repo dev log + these docs | Bash, Nix flake, Markdown |

The agent guide (`CLAUDE.md`) is canonical in `nikaudio-common` and copied to the
workspace root.

## System overview

```
                 ┌────────────────┐   HTTPS (cookie session / guest token)
   Browser ────▶ │  nikaudio-web  │
                 │  (Angular SPA) │
                 └───────┬────────┘
                         │ generated TS client → /api
                 ┌───────▼────────┐        ┌──────────────┐
                 │  nikaudio-be   │──GORM──▶  PostgreSQL  │
                 │   (Go / Gin)   │        └──────────────┘
                 │                │──────▶ filestore (local disk:
                 └───────▲────────┘         storage/audio, storage/covers)
                         │ bearer token, polling
                 ┌───────┴────────┐
                 │ nikaudio-worker│  claims job → gets BlockSnapshots →
                 │ (Kokoro TTS)   │  Kokoro ONNX → uploads .m4b + block metadata
                 └────────────────┘
```

The worker **polls** the backend; the backend never calls the worker. That keeps workers
firewall-friendly and lets a standing GPU box (the free path) and future serverless GPUs
(paid path) use the same protocol.

## Audio pipeline (the core flow)

1. Frontend creates/edits a book → backend parses text/EPUB into ordered `Block`s.
2. User queues a `BookVersion` (or block selection, as a sample) for audio.
3. Backend atomically snapshots block content into immutable `BlockSnapshot` rows and
   inserts a `Queue` row (`waiting`).
4. Worker polls `GET /api/worker/text`, claims the top job (`FOR UPDATE SKIP LOCKED`,
   sets `locked_at`, status `processing`), and receives the **snapshots** — never live
   blocks. Disabled snapshots are excluded from the payload.
5. Worker splits text near a ~200-phoneme sweet spot (Kokoro quality is length-sensitive),
   generates audio, reports progress via `POST /api/worker/status`.
6. Worker uploads the `.m4b` + per-block end timestamps and phoneme content to
   `POST /api/worker/audio/:hash_id`. Backend validates block IDs against the queued
   snapshots.
7. Backend stores the file, creates `AudioBook` + `AudioBlock` rows (linked back to
   `BlockSnapshotID`), synthesizes zero-length `AudioBlock`s for disabled blocks so the
   player timeline stays complete, and marks the queue row `done`.

Crash recovery: a stale `locked_at` on a `processing` row lets the job be reclaimed.

## Backend (`nikaudio-be`)

Go module `nikaudio`, entry `cmd/api/main.go`, router in `src/server/router.go`.

- `src/models` — GORM models · `src/dto` — request/response contracts (the explicit JSON
  contract with both frontend and worker) · `src/handlers` — HTTP handlers by domain
  (`auth`, `book`, `queue`, `worker`, `textAudio`, `public_book`, `settings`) ·
  `src/services` — business logic · `src/middleware` — auth/CORS/logging/`RequireAdmin`.
- `src/bookblocks` — block-order parsing/pagination/ordered fetch. **Always reuse this**
  instead of reparsing `BlockOrder` JSON in handlers.
- `src/db` — driver-aware connection + committed SQL migrations
  (`src/db/migrations/postgres`, run at startup; **not** `AutoMigrate`).
- `src/session` — DB-backed opaque cookie sessions · `src/mail` — email ·
  `src/platform/filestore` — storage abstraction (local disk is the only impl: audio
  under `storage/audio`, covers under `storage/covers`) · `docs` — generated Swagger ·
  `dummy_worker` — test client.

Key services: `audioqueue` (atomic queue + snapshots), `workerjobs` (claim jobs, build
payloads), `audioresults` (persist uploads, link audio metadata), `audiorequests`,
`audioqueries` (read models), `workers` (register/heartbeat/ingest), `books`,
`publicbooks` (catalog ingest/reads/publish/voting).

**Handler/service boundary:** handlers bind/validate input, resolve auth, do access
checks, map to DTOs. Anything opening transactions, mutating multiple tables, claiming
queue rows, or mapping stored audio belongs in `src/services`.

### API surface (route groups)

- **Auth**: `/api/auth/check`, `/api/login|logout|register|confirm-email|forgot-password|reset-password`
- **Books**: `/api/book/from-text|from-file|from-public-book`, `/api/books`,
  `/api/book/:book_id/...` (versions, make-private, audio-requests),
  `/api/book/version/:version_id/...` (get/update/search/export/branch/metadata/
  pronunciations/delete), `/api/voices`, `/api/langs`
- **Queue**: `/api/queue/book/:version_id`, `/api/queue/blocks/:version_id` (samples),
  `/api/queue/block/:block_id` (501 stub), `/api/queue/status/:queue_id`
- **Audio results**: `/api/result/:hash_id`, `/api/audio/:hash_id`,
  `/api/audio-chunk/:hash_id`, `/api/audio-requests`, `/api/request/...`,
  `/api/result/:hash_id/to-book`
- **Public-domain catalog**: `/api/public-books[...]` (list/detail/cover/suggest/vote),
  `/api/admin/public-books[...]` + `/api/admin/suggestions` (admin-only)
- **Worker**: `/api/worker/register` (shared token), then bearer-token:
  `/api/worker/text`, `/api/worker/status`, `/api/worker/audio/:hash_id`,
  `/api/worker/file/:audio_id` (501 stub)
- **Settings**: `/api/settings/user`

Swagger annotations generate `docs/` (`make swagger-check`), which in turn feeds the
frontend's generated client — the docs are part of the contract, keep them in sync.

### Auth model

| Actor | Mechanism |
| --- | --- |
| Registered user | DB-backed opaque session cookie (`withCredentials` on the frontend) |
| Guest | Guest token bound to a guest book, with expiry |
| Admin | `User.Role == "admin"` + `RequireAdmin` middleware; frontend role-guarded routes |
| Worker | Shared `WORKER_AUTH_TOKEN` to register → per-worker bearer token (hash stored) |

## Frontend (`nikaudio-web`)

Angular 20, zoneless change detection, signals-first. Entries: `src/main.ts`,
`app.config.ts`, `app.routes.ts`.

Routes: `/` create · `/books` · `/book/:id` editor · `/audio-requests` ·
`/audio-player/:id` · `/public-books` + `/public-books/:slug` · `/admin/public-books` ·
`/settings` · `/register` `/login` `/confirm-email` `/reset-password` · `/unreachable`.

Structure is feature-area based (`books/`, `audio/`, `account/`) with thin `core/` +
`shared/`:

- `core/api` — **generated** OpenAPI client. Never hand-edit; change backend
  Swagger/DTOs and regenerate (`npm run generate-api`).
- `core/auth` — auth/session state + guards · `core/http` — API config + error
  interceptor.
- `books/book-editor` — `book-editor-state.service.ts` (sync editor state/commands) +
  `book-editor.service.ts` (load/save/submit API workflow).
- `audio/audio-player` — `audio-player.service.ts` (result API workflow) +
  `audio-playback.service.ts` (audio element + blob URL lifecycle).
- A **shared virtual-scroll engine** drives both the book editor and the audio player
  block lists.
- Theming: semantic color tokens (`bg-surface`/`text-ink`/`border-line`, indigo accent)
  with class-based dark mode.

State conventions: feature services own writable signals privately and expose
`asReadonly()`; components mutate via command methods only. `computed()` for sync
derivations, `effect()` sparingly, `toSignal()` for route params, `takeUntilDestroyed()`
for long-lived streams. No global state library.

## Worker (`nikaudio-worker`)

`worker.py` is currently a local script: text file → paragraphs → Misaki phonemes →
Kokoro ONNX audio → concatenated WAV under `./output`. It already contains draft
structures for backend integration (`Paragraph`, `TtsRequest`, `ModelParagraph`,
`split_for_optimal_quality`, `get_model_paragraphs`). The production daemon (poll →
process → upload) is on the roadmap. `playground*`, `old`, `bench`,
`shell-for-kokoro` are experiments — keep production logic out of them.

Key domain insight: Kokoro quality degrades on long inputs — target ~200 phonemes/tokens
per synthesis chunk, splitting long paragraphs by punctuation, then words, while
**preserving block boundaries and timing** in the output metadata.

## Deployment (`nikaudio-common`)

- `scripts/deploy_v2.sh` — configurable deploy: loads `config/deploy/{dev,prod}.config`,
  builds the Go backend + Angular frontend, tests SSH, creates server dirs, copies
  binary/`.env`/Angular output; `--create-service` writes a systemd unit;
  `--skip-build` reuses artifacts. (`deploy.sh` is the older version.)
- `scripts/deploy_landing.sh` — deploys the static landing site;
  `config/nginx.landing.config.example` for its vhost.
- `config/nginx.config.example` — app vhost example. Config files are
  environment-specific; no hard-coded secrets.
- Prod API: `https://nikaudio.anotherroot.eu/api`.

## Local ports

- Backend `http://localhost:3030`, API base `/api`, Swagger
  `http://localhost:3030/swagger/index.html`
- Frontend `http://localhost:3031` (dev server host `127.0.0.1:3031`)
