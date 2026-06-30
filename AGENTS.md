# Nikaudio Agent Guide

This workspace contains four separate repositories that together make the
Nikaudio product:

- `nikaudio-web`: Angular frontend.
- `nikaudio-be`: Go API/backend.
- `nikaudio-worker`: Python/Kokoro TTS worker experiments and worker runtime.
- `nikaudio-common`: shared deployment/configuration scripts.

The top-level directory is not itself a git repository. Check git status inside
each subproject before editing, and do not assume changes in one folder are
tracked with changes in another.

## Product Goal

Nikaudio is a web app for turning EPUB or text books into audiobooks with the
open source Kokoro TTS model. The long-term goal is twofold:

1. Provide useful, cheap, high-quality AI audiobook generation.
2. Build a public repository of free public-domain audiobooks.

The default free path uses a standing GPU worker, expected to run continuously on
an RTX 3060-class machine. Users wait in a queue when demand exceeds available
worker capacity. A paid fast path is planned: users can pay near-cost pricing to
send private jobs to instant serverless GPU capacity.

Public-domain books are intended to become shared public assets. Once a
public-domain book is processed, its audiobook should be available to everyone.
User-uploaded private books must remain private.

Important planned product features:

- Public-domain book catalog hosted directly in Nikaudio.
- Shared pronunciation dictionaries for book-specific names and words.
- Algorithms that improve pronunciations over time from user corrections.
- Block-level audiobook patching. Books are divided into blocks, usually
  paragraphs. A user should be able to regenerate selected blocks with corrected
  pronunciations and patch an existing audiobook, for example a better version of
  a paragraph in Frankenstein.

## System Shape

Current local development ports:

- Backend: `http://localhost:3030`
- Frontend: `http://localhost:3031`
- API base path: `/api`
- Swagger docs: `http://localhost:3030/swagger/index.html`

Typical flow:

1. Frontend creates or edits a book.
2. Backend parses text/EPUB into ordered blocks.
3. User queues a book version for audio generation.
4. Backend snapshots block content for the request and creates a queue row.
5. Worker polls the backend for the next job.
6. Backend returns the immutable block snapshots for the claimed job, not live
   editable book blocks.
7. Worker generates audio with Kokoro ONNX and submits an `.m4b` plus block
   timing/phoneme metadata.
8. Backend stores the audio file, links audio block metadata back to the source
   block snapshots, marks the request done, and the frontend can play the result.

The product model is block-centric. Preserve that mental model when adding
features: books have versions, versions have ordered blocks, audio output should
retain enough block metadata to support playback, search, pronunciation work,
and future patching.

## `nikaudio-be`

Go backend using:

- Go module `nikaudio`.
- Gin for HTTP routing.
- GORM with PostgreSQL for application persistence.
- `golang-migrate` SQL migrations under `src/db/migrations/postgres`.
- DB-backed opaque cookie sessions for normal users.
- Bearer-style token auth for workers.
- `swaggo`/Swagger annotations for API docs.
- `godotenv` for local `.env` loading.

Main entry point:

- `cmd/api/main.go`

Key folders:

- `src/bookblocks`: block-order parsing, pagination, and ordered block fetch
  helpers.
- `src/models`: GORM models.
- `src/handlers`: HTTP handlers grouped by domain.
- `src/services`: backend business logic used by handlers. Keep transaction
  logic and domain workflows here when possible.
- `src/dto`: request/response contracts.
- `src/middleware`: auth, CORS, logging helpers.
- `src/db`: driver-aware DB connection, Postgres migrations, optional env-gated
  admin seed.
- `src/mail`: email delivery helpers.
- `src/session`: DB-backed session store plus in-memory test utility.
- `src/platform/filestore`: narrow audio file storage abstraction.
- `docs`: generated Swagger output.
- `storage/audio`: local generated audio storage.
- `dummy_worker`: simple worker client/testing code.

Important service packages:

- `src/services/audioqueue`: queues book audio requests atomically, creates
  immutable `BlockSnapshot` rows, and creates the queue row.
- `src/services/workerjobs`: claims worker jobs and builds worker payloads from
  snapshots.
- `src/services/audioresults`: persists worker audio uploads, creates linked
  audio block metadata, and maps stored audio results for playback.
- `src/services/audiorequests`: authenticated audio request list/delete/source
  workflows.
- `src/services/audioqueries`: audio result/status/chunk metadata read models.
- `src/services/workers`: worker registration, heartbeat/status, and audio
  ingestion orchestration.
- `src/services/books`: book creation, parsing, reads, and version update
  workflows.

Important models:

- `Book`: owner/guest metadata and book identity.
- `BookVersion`: editable version of a book. `BlockOrder` is JSON containing
  ordered block IDs.
- `Block`: paragraph/chapter-title units used for editing and TTS.
- `AudioRequest`: queued work request.
- `BlockSnapshot`: immutable copy of queued block content, order, voice, and
  language at request time. Workers should process snapshots, not live blocks.
- `Queue`: queue status, type, worker ownership, and crash-recovery lock time.
- `Worker`: registered worker token hash and type.
- `AudioBook`: generated audio file plus length and ownership.
- `AudioBlock`: timing and phoneme metadata for generated audio blocks. New
  rows should link to `BlockSnapshotID` so future patching can identify the
  exact generated source text.

Important handlers:

- `auth.go`: registration, login, email confirmation, password reset.
- `book.go`: create books from text/file/public-book, parse blocks, update
  versions, access checks.
- `queue.go`: queue book audio and report queue status.
- `worker.go`: worker registration, polling, status updates, audio upload.
- `textAudio.go`: result and audio-serving endpoints.
- `settings.go`: user settings.

Handler/service boundary:

- Handlers should bind/validate HTTP input, resolve auth/session context,
  perform access checks, and map service results to DTOs.
- Business workflows should live under `src/services`, especially anything that
  opens transactions, mutates multiple tables, claims queue rows, or maps stored
  audio metadata.
- Reuse `src/bookblocks` for `BlockOrder` parsing, pagination, and ordered block
  fetching. Do not reconstruct block order with ad hoc JSON parsing in handlers.

Worker endpoints:

- `POST /api/worker/register`: register worker with admin/service auth token.
- `GET /api/worker/text`: claim next queued request.
- `POST /api/worker/status`: update queue progress.
- `POST /api/worker/audio/:hash_id`: upload generated audio.

Notes and cautions:

- `RequestBlockAudio` and `GetWorkerFile` currently return `501 Not
  Implemented` and are not production-ready.
- PostgreSQL is the runtime/default database. SQLite remains only for explicit
  throwaway local/unit tests with GORM `AutoMigrate`; SQLite migrations are not
  maintained.
- Application startup runs committed Postgres migrations and does not run GORM
  `AutoMigrate`.
- Worker queue claiming uses PostgreSQL `FOR UPDATE SKIP LOCKED`; tests that
  depend on Postgres behavior are gated by `TEST_DATABASE_DSN`.
- Generated audio storage goes through `src/platform/filestore.FileStore`; local
  disk storage under `storage/audio` is the only implementation for now.
- Generated Swagger docs feed the Angular OpenAPI client. When backend DTOs or
  routes change, regenerate docs and then regenerate the frontend client.
- Keep generated Swagger docs in sync with annotations. `make swagger-check`
  verifies drift.
- Be careful with block ordering. `BlockOrder` is authoritative for playback and
  processing order, not database row order. Once a job is queued,
  `BlockSnapshot.OrderIndex` is the authoritative order for that audio request.
- Worker payloads must be built from `BlockSnapshot` rows. Editing a book after
  queueing must not alter the content a worker processes for the already-queued
  request.
- Audio result views should prefer `AudioBlock.BlockSnapshotID` and snapshot
  content. Legacy fallback to live block order exists only for old rows without
  snapshots.
- Preserve access rules: owned books require owner auth; guest books use guest
  tokens; future public-domain books need explicit public/private semantics.

Useful commands:

```sh
cd nikaudio-be
nix develop
docker compose up -d postgres
go run ./cmd/api
make fmt-check
make lint
make test
make swagger-check
```

Local backend environment:

- Use `DB_DRIVER=postgres` for normal local development.
- The default local Postgres settings match `nikaudio-be/docker-compose.yml`:
  `DB_HOST=localhost`, `DB_PORT=5432`, `DB_NAME=nikaudio`,
  `DB_USER=nikaudio`, `DB_PASSWORD=nikaudio`, `DB_SSL_MODE=disable`.
- Set `WORKER_AUTH_TOKEN` to a local secret used by `POST /api/worker/register`.
- Set `TEST_DATABASE_DSN` only when intentionally running Postgres integration
  tests; those tests create and drop isolated schemas in the configured
  database.

## `nikaudio-web`

Angular frontend using:

- Angular 20.
- TypeScript 5.9.
- SCSS component styles.
- Angular zoneless change detection.
- Angular Router.
- Angular HTTP client with a functional error interceptor.
- Tailwind CSS 4 dependency/tooling.
- Generated TypeScript Angular API client from backend OpenAPI docs.

Main entry points:

- `src/main.ts`
- `src/app/app.config.ts`
- `src/app/app.routes.ts`

Current routes:

- `/`: create a book.
- `/books`: list user books.
- `/book/:id`: edit a book version and blocks.
- `/audio-requests`: list audio generation requests.
- `/audio-player/:id`: play generated audio.
- `/settings`: authenticated user settings.
- `/register`, `/login`, `/confirm-email`, `/reset-password`.
- `/unreachable`: server/network failure page.

Key frontend areas:

- `src/app/books/create-book`: text/file book creation flow.
- `src/app/books/books-list`: user book list.
- `src/app/books/book-editor`: block editing and book version update flow.
- `src/app/books/book-editor/book-editor-state.service.ts`: editor selection,
  dirty tracking, block mutation, deleted-block tracking, and book-name state.
- `src/app/books/book-editor/book-editor.service.ts`: book-editor API/workflow
  state for loading, saving, and submitting a book version.
- `src/app/books/block` and `src/app/books/block-virtual-scroll`: editable
  block display and editor virtual scrolling helpers.
- `src/app/audio/audio-requests`: queued/processed request list.
- `src/app/audio/audio-player`: generated audio playback screen.
- `src/app/audio/audio-player/audio-player.service.ts`: audio-result API
  workflow state for audiobook metadata, paging, audio chunk loading, and toast
  errors.
- `src/app/audio/audio-player/audio-playback.service.ts`: local audio element
  playback state and blob URL lifecycle.
- `src/app/audio/audio-block` and `src/app/audio/audio-block-virtual-scroll`:
  audio block display and virtual scrolling helpers.
- `src/app/core/auth`: frontend auth/session state and guards.
- `src/app/core/http`: API configuration and functional HTTP interceptor.
- `src/app/core/api`: generated OpenAPI Angular client. Do not hand-edit.
- `src/app/shared/layout`: layout shell components such as page layout and user
  header.
- `src/app/shared/ui`: reusable generic UI components such as dropdown input
  and toast.

Frontend refactor status:

- The broad cleanup refactor is currently paused so feature work can continue.
- Current structure is feature-area based under `books/`, `audio/`, `account/`,
  with small `core/` and `shared/` layers.
- The generated client is isolated under `src/app/core/api`.
- Book editor state has been split into focused services:
  `book-editor-state.service.ts` owns synchronous editor state and commands;
  `book-editor.service.ts` owns API workflows and loading/saving/submitting
  signals.
- Audio player workflow loading has been split into `audio-player.service.ts`;
  the component should stay focused on route, scroll, sidebar, and presentation
  coordination.
- Route parameter streams in book editor and audio player use `toSignal(...)`
  with `effect(...)` for route-driven loading.
- The project has ESLint/Prettier/build/test wired through `npm run check`.
- Remaining cleanup items are intentionally deferred unless a feature touches
  that area: richer inline form validation messages, toast/error consistency,
  style cleanup, API generation documentation, and focused service tests.

Generated client rule:

- Do not manually edit `src/app/core/api` unless the task is explicitly about
  generated-code handling. Prefer changing backend Swagger annotations/DTOs and
  running the generator.

API client generation:

```sh
cd nikaudio-web
npm run generate-api
```

The generator expects the backend to be running at
`http://localhost:3030/swagger/doc.json`.

Useful commands:

```sh
cd nikaudio-web
nix develop
npm install
npm start
npm run build
npm test
npm run check
```

Local environment:

- Development API URL: `http://localhost:3030/api`.
- Production API URL: `https://nikaudio.anotherroot.eu/api`.
- Dev server host/port are configured as `127.0.0.1:3031`.

Frontend standards:

- Follow existing Angular component structure: `.ts`, `.html`, `.scss`, `.spec.ts`
  where tests exist.
- Keep UI practical and workflow-focused. This is an audiobook creation/editor
  app, not a marketing landing page.
- Use the generated API services for backend calls when possible.
- Preserve cookie credentials. The generated API `Configuration` is created with
  `withCredentials: true`.
- Keep backend API calls out of presentation components when a workflow includes
  mapping, paging, loading/error state, queue submission, or multiple related
  requests. Put that workflow in a focused feature service next to the owning
  feature.
- Feature services with mutable signal state should keep writable signals
  private and expose readonly signals with `asReadonly()`. Use explicit command
  methods for mutations.
- Use `computed(...)` for synchronous derivations from signals. Use
  `effect(...)` sparingly, mainly for route-driven or integration side effects.
- Prefer `toSignal(...)` for route/query params that are component state. Use
  `takeUntilDestroyed(...)` for long-lived streams that remain subscriptions.
- Keep one-shot user-action API subscriptions simple, but move them to a
  feature service when the component starts owning workflow state.
- Keep component-only UI state local to the component. Examples: sidebar open
  flags, simple input focus state, and local presentation toggles.
- Do not mutate readonly service signals from components. Add a service command
  method instead.
- Do not add a global state library during routine feature work.
- For book editor changes, preserve `BlockId` support for both persisted numeric
  IDs and local string IDs until new blocks are saved and reconciled.
- For audio player changes, keep audio element/blob URL lifecycle in
  `audio-playback.service.ts`, not in the component.
- Prefer generated DTOs at API boundaries. Use local view-model wrappers only
  when UI-only fields are needed.
- When touching forms, prefer inline validation messages for field-level
  validation and keep page-local recoverable errors local. Use the toast service
  for cross-screen workflow results or unexpected global failures.
- Run `npm run check` after frontend refactor-style changes. For small feature
  edits, at minimum run the relevant formatter/lint/build command when feasible.

## `nikaudio-worker`

Python worker and Kokoro experimentation area using:

- Python 3.12 in Nix/uv environments.
- `kokoro-onnx`.
- `misaki-fork[en]` for G2P/phoneme conversion.
- `onnxruntime` for CPU.
- `onnxruntime-gpu` for CUDA.
- `soundfile`, `numpy`, `ffmpeg`, `espeak-ng`.

Main current worker file:

- `worker.py`

The current root `worker.py` is still a local/file-oriented worker script rather
than a complete backend-polling production worker. It reads a text file, splits
content into paragraphs, converts text to phonemes with Misaki, generates Kokoro
audio, concatenates chunks, and writes a WAV file under `./output`.

The script also contains draft data structures and chunking work for future
backend integration:

- `Paragraph`
- `TtsRequest`
- `ModelParagraph`
- `split_for_optimal_quality`
- `get_model_paragraphs`

Worker runtime concepts:

- Kokoro quality is sensitive to input length. The current code targets a
  phoneme/token sweet spot around 200 and splits long paragraphs by punctuation
  and then words.
- Future production worker work should poll `GET /api/worker/text`, process each
  block, report progress via `POST /api/worker/status`, and upload final audio
  plus block metadata to `POST /api/worker/audio/:hash_id`.
- Uploaded block metadata should include block IDs, end timestamps in
  milliseconds, and phoneme/foname content. The backend validates these IDs
  against the queued snapshots and stores `AudioBlock` rows linked to the
  matching `BlockSnapshot`.

Nix dev shells:

```sh
cd nikaudio-worker
nix develop .#cpu
nix develop .#gpu
```

CPU shell installs `onnxruntime`; GPU shell installs `onnxruntime-gpu` and sets
`ONNX_PROVIDER=CUDAExecutionProvider`.

Example local run:

```sh
cd nikaudio-worker
python worker.py input/test.txt af_heart 1.0
```

The flake downloads Kokoro model files if missing:

- `kokoro-v1.0.onnx`
- `voices-v1.0.bin`

Other folders:

- `playground`, `playground2`, `playground3`: experiments and benchmarks.
- `old`: older worker/client sketches.
- `bench`: benchmark notes/results.
- `shell-for-kokoro`: older/manual shell setup.

Standards for worker work:

- Keep production worker logic separate from one-off playground scripts.
- Preserve block boundaries and timing metadata. Future patching depends on it.
- Prefer structured request/response parsing over ad hoc text formats.
- Avoid committing generated audio/model artifacts unless explicitly intended.

## `nikaudio_common`

Shared deployment/configuration repository.

Contents:

- `scripts/deploy.sh`: older generic deployment script.
- `scripts/deploy_v2.sh`: current configurable deployment script.
- `config/deploy/dev.config`: development server deployment config.
- `config/deploy/prod.config`: production placeholder config.
- `config/nginx.config.example`: example nginx config for Angular plus API proxy.
- `flake.nix`: shell with Node, Go, and Air.

`deploy_v2.sh` behavior:

- Loads `./config/deploy/dev.config`.
- Builds the Go backend for configured OS/architecture.
- Builds the Angular frontend.
- Tests SSH connectivity.
- Creates backend/frontend/audio directories on the server.
- Copies the backend binary and optional `.env`.
- Copies Angular build output into the nginx-served directory.
- Can create a systemd service with `--create-service`.
- Supports `--skip-build`.

Useful commands:

```sh
cd nikaudio_common
nix develop
./scripts/deploy_v2.sh --help
./scripts/deploy_v2.sh
```

Deployment cautions:

- Treat config files as environment-specific. Do not hard-code secrets in scripts.
- Check paths before changing deploy scripts because the project is split across
  sibling repositories.
- Production/test deploy scripts are planned; keep new script structure reusable
  instead of baking every environment into one branch of shell logic.

## Cross-Repo Development Workflow

Backend plus frontend:

```sh
cd nikaudio-be
air

cd ../nikaudio-web
npm start
```

When changing API contracts:

1. Update backend models/DTOs/handlers and Swagger annotations.
2. Regenerate backend Swagger docs if the project uses a local `swag` command.
3. Start backend on `localhost:3030`.
4. Run `npm run generate-api` in `nikaudio-web`.
5. Update Angular code to use regenerated types/services.
6. Build/test both sides.

When changing queue/worker behavior:

1. Update backend DTOs and worker handlers first.
2. Keep the JSON contract explicit in `src/dto`.
3. Update worker parsing/upload logic.
4. Verify queue states: `waiting`, `processing`, `done`.
5. Verify crash/recovery behavior around `locked_at` if relevant.

## Coding Standards for Agents

- Read the relevant subproject before editing. This workspace is evolving and
  contains experiments.
- Keep changes scoped to the requested behavior.
- Do not rewrite generated API client code by hand.
- Preserve user privacy boundaries between public-domain books and private user
  uploads.
- Preserve block identity, order, and timing metadata whenever touching book,
  queue, worker, or playback code.
- Prefer small, testable functions for parsing, access checks, queue transitions,
  and worker protocol logic.
- Add or update focused tests for backend handlers/models and frontend services
  when changing behavior with meaningful risk.
- Use `rg` for repository searches.
- Check status inside each repository you edit.
- Do not revert unrelated local changes.

## Known Rough Edges

- The worker root script is not yet a fully integrated backend-polling daemon.
- Some backend routes are registered but not implemented safely, notably block
  audio queueing and worker file download.
- Backend tests are currently sparse/placeholders.
- SQLite/local disk storage are fine for development but will need careful
  production decisions for concurrency, backups, and audio serving.
- Public-domain catalog, shared pronunciation dictionaries, paid serverless GPU
  processing, and block-level patching are product goals but not complete
  systems yet.
