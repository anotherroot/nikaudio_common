# Nikaudio Agent Guide

Nikaudio turns EPUB/text books into audiobooks with the open-source Kokoro TTS model.
This workspace is **five separate git repositories** (the top-level dir is *not* a repo):

- `nikaudio-web` — Angular 20 frontend.
- `nikaudio-be` — Go API/backend.
- `nikaudio-worker` — Python/Kokoro TTS worker.
- `nikaudio-landing` — static Librofono landing site.
- `nikaudio-common` — shared deploy/config scripts, project docs, + the cross-repo dev log (this repo).

Check `git status` inside each subproject before editing; changes in one folder are not
tracked with another.

**Project documentation** lives in `nikaudio-common/docs/` (start at `docs/README.md`):
`001-vision` · `002-features` · `003-architecture` · `004-data-model` ·
`005-development` · `006-roadmap`. This guide is the condensed version; the docs carry
the full picture — consult them for anything this file only summarizes, and update the
affected doc when features or architecture change.

## Product goal

1. Cheap, high-quality AI audiobook generation.
2. A public repository of free public-domain audiobooks.

Free path uses a standing GPU worker (RTX 3060-class, always on); users queue when demand
exceeds capacity. A paid fast path (near-cost serverless GPU for private jobs) is planned.
Public-domain audiobooks become shared assets once processed; user-uploaded private books
stay private.

Planned features: public-domain catalog, shared pronunciation dictionaries, pronunciation
improvement from user corrections, and **block-level audiobook patching** (regenerate
selected blocks and patch an existing audiobook).

## Core mental model — block-centric

Books have **versions**; versions have **ordered blocks** (usually paragraphs). Audio output
retains block metadata to support playback, search, pronunciation work, and future patching.
Preserve this model when adding features.

Typical flow:

1. Frontend creates/edits a book.
2. Backend parses text/EPUB into ordered blocks.
3. User queues a book version for audio.
4. Backend snapshots block content into immutable `BlockSnapshot` rows + a queue row.
5. Worker polls backend, claims a job, and receives the **snapshots** (not live blocks).
6. Worker generates audio (Kokoro ONNX), submits `.m4b` + block timing/phoneme metadata.
7. Backend stores audio, links `AudioBlock` metadata back to the snapshots, marks done.

Key invariants (do not break):

- `BlockOrder` (JSON on `BookVersion`) is authoritative order, **not** DB row order. Once
  queued, `BlockSnapshot.OrderIndex` is authoritative for that request.
- Worker payloads are always built from `BlockSnapshot`. Editing a book after queueing must
  not change what an already-queued worker processes.
- New `AudioBlock` rows link to `BlockSnapshotID` so patching can find the exact source text.
- Preserve access rules: owned books need owner auth; guest books use guest tokens;
  public-domain vs private books need explicit public/private semantics.

## Local dev ports

- Backend `http://localhost:3030`, API base `/api`, Swagger `http://localhost:3030/swagger/index.html`
- Frontend `http://localhost:3031` (dev server host `127.0.0.1:3031`)
- Prod API: `https://nikaudio.anotherroot.eu/api`

## Live dev environment

The stack usually already runs in tmux — don't start second instances (ports clash):

- **Backend** (air, rebuilds on save): pane `Nikaudio BE:0.1`. **After BE edits**, confirm the
  rebuild: `tmux capture-pane -p -t 'Nikaudio BE:0.1' -S -60` (compile errors also land in
  `nikaudio-be/tmp/build-errors.log`).
- **Frontend** (`npm start`, rebuilds on save): pane `Nikaudio FE - web:0.1`, serves
  `http://localhost:3031`. After FE edits, check the pane for "Application bundle generation
  complete" vs compile errors.
- **Postgres** (docker): `docker compose -f nikaudio-be/docker-compose.yml exec -T postgres
  psql -U nikaudio -d nikaudio -c "SQL"` — prefer SELECTs; announce mutations first.
- **Skills**: `be-api` (curl the API — auth jars, guest/worker flows, queue recipes) and
  `fe-shot` (headless light/dark FE screenshots). Canonical in `nikaudio-common/skills/`,
  symlinked into `.claude/skills/`.

---

## `nikaudio-be` (Go backend)

Go module `nikaudio`. Gin router, GORM + PostgreSQL, `golang-migrate` SQL migrations
(`src/db/migrations/postgres`), DB-backed opaque cookie sessions (users), bearer token auth
(workers), `swaggo`/Swagger, `godotenv`. Entry: `cmd/api/main.go`.

Layout:

- `src/models` GORM models · `src/dto` request/response contracts · `src/handlers` HTTP
  handlers by domain · `src/services` business logic · `src/middleware` auth/CORS/logging.
- `src/bookblocks` block-order parsing/pagination/ordered fetch — **reuse this**, don't
  reparse `BlockOrder` JSON ad hoc in handlers.
- `src/db` driver-aware connection + migrations · `src/session` session store · `src/mail`
  email · `src/platform/filestore` audio storage abstraction (local disk `storage/audio` is
  the only impl) · `docs` generated Swagger · `dummy_worker` test client.

Key services: `audioqueue` (atomic queue + snapshots), `workerjobs` (claim jobs, build
payloads), `audioresults` (persist uploads, link audio metadata), `audiorequests`,
`audioqueries` (read models), `workers` (register/heartbeat/ingest), `books`.

Key models: `Book`, `BookVersion` (`BlockOrder` JSON), `Block`, `AudioRequest`,
`BlockSnapshot`, `Queue` (status/owner/`locked_at`), `Worker`, `AudioBook`, `AudioBlock`.

Handlers: `auth.go`, `book.go`, `queue.go`, `worker.go`, `textAudio.go`, `settings.go`.

Handler/service boundary: handlers bind/validate input, resolve auth, do access checks, map
to DTOs. Anything opening transactions, mutating multiple tables, claiming queue rows, or
mapping stored audio belongs in `src/services`.

Worker endpoints: `POST /api/worker/register`, `GET /api/worker/text` (claim),
`POST /api/worker/status`, `POST /api/worker/audio/:hash_id`.

Cautions:

- PostgreSQL is the runtime DB. SQLite is only for throwaway unit tests via `AutoMigrate`;
  its migrations are not maintained. Startup runs committed Postgres migrations, not `AutoMigrate`.
- Queue claiming uses `FOR UPDATE SKIP LOCKED`; Postgres-dependent tests are gated by `TEST_DATABASE_DSN`.
- `RequestBlockAudio` and `GetWorkerFile` return `501` and are not production-ready.
- Keep Swagger docs in sync with annotations (`make swagger-check`); they feed the frontend client.

Commands:

```sh
cd nikaudio-be && nix develop
docker compose up -d postgres
go run ./cmd/api        # or: air
make fmt-check lint test swagger-check
```

Local env: `DB_DRIVER=postgres`; defaults match `docker-compose.yml`
(`DB_HOST=localhost DB_PORT=5432 DB_NAME=nikaudio DB_USER=nikaudio DB_PASSWORD=nikaudio
DB_SSL_MODE=disable`). Set `WORKER_AUTH_TOKEN` for worker registration. Set
`TEST_DATABASE_DSN` only when running Postgres integration tests (they create/drop schemas).

---

## `nikaudio-web` (Angular frontend)

Angular 20, TS 5.9, SCSS, zoneless change detection, Router, functional HTTP error
interceptor, Tailwind 4, and a generated TS API client. Entries: `src/main.ts`,
`app.config.ts`, `app.routes.ts`.

Routes: `/` create · `/books` list · `/book/:id` edit · `/audio-requests` · `/audio-player/:id`
· `/settings` · `/register` `/login` `/confirm-email` `/reset-password` · `/unreachable`.

Structure is feature-area based (`books/`, `audio/`, `account/`) with thin `core/` + `shared/`:

- `core/api` — generated OpenAPI client. **Do not hand-edit** (see rule below).
- `core/auth` auth/session state + guards · `core/http` API config + interceptor.
- `books/book-editor` — `book-editor-state.service.ts` (sync editor state/commands: selection,
  dirty, block mutation, deleted-block tracking, name) + `book-editor.service.ts` (load/save/submit API workflow).
- `audio/audio-player` — `audio-player.service.ts` (result API workflow: metadata, paging,
  chunk loading, toasts) + `audio-playback.service.ts` (audio element + blob URL lifecycle).
- `books/block[-virtual-scroll]`, `audio/audio-block[-virtual-scroll]`, `shared/layout`, `shared/ui`.

Frontend standards:

- Keep backend calls out of presentation components when a workflow involves mapping, paging,
  loading/error state, queue submission, or multiple requests — put it in a feature service
  next to the feature. One-shot user-action calls can stay in the component.
- Feature services: keep writable signals private, expose `asReadonly()`, mutate via command
  methods. Never mutate readonly service signals from components.
- `computed()` for sync derivations; `effect()` sparingly (route-driven/integration side
  effects); `toSignal()` for route/query params that are component state;
  `takeUntilDestroyed()` for long-lived streams. Keep pure UI state (sidebar flags, focus)
  local to the component.
- Preserve cookie creds (generated `Configuration` uses `withCredentials: true`). Prefer
  generated DTOs at API boundaries; local view-models only for UI-only fields.
- Book editor: keep `BlockId` support for both persisted numeric IDs and local string IDs
  until new blocks are saved/reconciled. Audio player: keep audio/blob lifecycle in
  `audio-playback.service.ts`.
- Forms: inline messages for field-level validation, page-local errors stay local, toast
  service for cross-screen results or unexpected global failures.
- No global state library during routine feature work.
- Follow existing `.ts`/`.html`/`.scss`/`.spec.ts` structure. Run `npm run check` after
  refactors; at minimum run relevant lint/build for small edits.

Commands:

```sh
cd nikaudio-web && nix develop
npm install && npm start
npm run build && npm test
npm run check           # eslint + prettier + build + test
npm run generate-api    # regen client; backend must be up at :3030/swagger/doc.json
```

> Toolchain note: node/npm may not be on PATH (Nix flake). See auto-memory
> `nikaudio-web-toolchain-path` and `nikaudio-web-api-client-regen` for the offline workaround.

---

## `nikaudio-worker` (Python/Kokoro)

Python 3.12 (Nix/uv), `kokoro-onnx`, `misaki-fork[en]` (G2P/phonemes), `onnxruntime`(-gpu),
`soundfile`, `numpy`, `ffmpeg`, `espeak-ng`. Main file: `worker.py`.

`worker.py` is still a local/file-oriented script (reads a text file → paragraphs → Misaki
phonemes → Kokoro audio → concatenated WAV under `./output`), plus draft structures for
backend integration (`Paragraph`, `TtsRequest`, `ModelParagraph`, `split_for_optimal_quality`,
`get_model_paragraphs`).

Concepts: Kokoro quality is length-sensitive — target a ~200 phoneme/token sweet spot,
splitting long paragraphs by punctuation then words. Future production worker should poll
`GET /api/worker/text`, process blocks, report `POST /api/worker/status`, and upload audio +
per-block metadata (block IDs, end timestamps in ms, phoneme/foname content) to
`POST /api/worker/audio/:hash_id`. Backend validates IDs against queued snapshots.

```sh
cd nikaudio-worker
nix develop .#cpu       # onnxruntime
nix develop .#gpu       # onnxruntime-gpu, ONNX_PROVIDER=CUDAExecutionProvider
python worker.py input/test.txt af_heart 1.0
```

Flake downloads `kokoro-v1.0.onnx` + `voices-v1.0.bin` if missing. Other dirs:
`playground*`, `old`, `bench`, `shell-for-kokoro` (experiments). Standards: keep production
logic out of playground scripts; preserve block boundaries + timing; prefer structured
request/response over ad hoc text; don't commit generated audio/model artifacts.

---

## `nikaudio-common` (deploy/config)

- `scripts/deploy_v2.sh` current configurable deploy (older: `deploy.sh`).
- `config/deploy/{dev,prod}.config`, `config/nginx.config.example`, `flake.nix` (Node/Go/Air).
- `devlog/` — cross-repo dev log (below).

`deploy_v2.sh`: loads `config/deploy/dev.config`, builds Go backend + Angular frontend, tests
SSH, creates server dirs, copies binary/`.env`/Angular output, optional `--create-service`
(systemd), supports `--skip-build`. Run `./scripts/deploy_v2.sh --help`.

Cautions: config files are environment-specific (no hard-coded secrets); check paths since
the project spans sibling repos; keep new script structure reusable across environments.

---

## Dev log (`nikaudio-common/devlog/`)

Records what we work on and why, for future sessions — context not obvious from code/git.

- `DEVLOG.md` — project index, one line per feature, grouped `Doing`/`Waiting`/`Done`.
- `doing/`, `waiting/`, `done/` — one file per feature: short goal/decisions header + a
  reverse-chronological timestamped log (`## YYYY-MM-DD — <what/why>`).

Maintain it: create `doing/<slug>.md` when starting a feature (+ link in `DEVLOG.md`); append
a timestamped entry as you work (record decisions/rationale, not the diff); move the file
between folders and update `DEVLOG.md` as status changes. The log is intentionally cross-repo
— keep it here even when the code lives in another repo.

## Cross-repo workflows

**API contract change:** update backend models/DTOs/handlers + Swagger annotations → regen
Swagger docs → start backend on :3030 → `npm run generate-api` in web → update Angular to use
new types → build/test both sides.

**Queue/worker change:** update backend DTOs + worker handlers first → keep the JSON contract
explicit in `src/dto` → update worker parsing/upload → verify queue states
(`waiting`/`processing`/`done`) → verify crash recovery around `locked_at`.

## Coding standards for agents

- Read the relevant subproject before editing (this workspace has experiments). Keep changes
  scoped to the request; don't revert unrelated local changes. Use `rg` for searches.
- Never hand-edit the generated API client (`nikaudio-web/src/app/core/api`) — change backend
  Swagger/DTOs and regenerate.
- Preserve privacy boundaries (public-domain vs private uploads) and block identity/order/timing
  whenever touching book, queue, worker, or playback code.
- Prefer small testable functions for parsing, access checks, queue transitions, worker
  protocol. Add/update focused tests for backend handlers/models and frontend services on
  meaningful behavior changes.
- Keep the dev log current (see above).

## Known rough edges

- Worker root script is not yet a full backend-polling daemon.
- Some backend routes are registered but unimplemented (block audio queueing, worker file download).
- Backend tests are sparse/placeholder.
- SQLite/local-disk storage are dev-only; production needs concurrency/backup/serving decisions.
- Public-domain catalog, shared pronunciation dictionaries, paid serverless GPU, and
  block-level patching are goals, not finished systems.
</content>
</invoke>
