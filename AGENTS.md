# Nikaudio Agent Guide

This workspace contains four separate repositories that together make the
Nikaudio product:

- `nikaudio-web`: Angular frontend.
- `nikaudio-be`: Go API/backend.
- `nikaudio-worker`: Python/Kokoro TTS worker experiments and worker runtime.
- `nikaudio_common`: shared deployment/configuration scripts.

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
6. Worker generates audio with Kokoro ONNX and submits an `.m4b` plus block
   timing/phoneme metadata.
7. Backend stores the audio file, audio block metadata, marks the request done,
   and the frontend can play the result.

The product model is block-centric. Preserve that mental model when adding
features: books have versions, versions have ordered blocks, audio output should
retain enough block metadata to support playback, search, pronunciation work,
and future patching.

## `nikaudio-be`

Go backend using:

- Go module `nikaudio`.
- Gin for HTTP routing.
- GORM with SQLite (`app.db`) for persistence.
- Cookie sessions for normal users.
- Bearer-style token auth for workers.
- `swaggo`/Swagger annotations for API docs.
- `godotenv` for local `.env` loading.

Main entry point:

- `main.go`

Key folders:

- `src/models`: GORM models.
- `src/handlers`: HTTP handlers grouped by domain.
- `src/dto`: request/response contracts.
- `src/middleware`: auth, CORS, logging helpers.
- `src/db`: SQLite connection and local seed user.
- `src/mail`: email delivery helpers.
- `src/session`: in-memory/session utilities.
- `docs`: generated Swagger output.
- `storage/audio`: local generated audio storage.
- `dummy_worker`: simple worker client/testing code.
- `tests`: current Go tests. Some are placeholders and may intentionally fail.

Important models:

- `Book`: owner/guest metadata and book identity.
- `BookVersion`: editable version of a book. `BlockOrder` is JSON containing
  ordered block IDs.
- `Block`: paragraph/chapter-title units used for editing and TTS.
- `AudioRequest`: queued work request.
- `Queue`: queue status, type, worker ownership, and crash-recovery lock time.
- `Worker`: registered worker token hash and type.
- `AudioBook`: generated audio file plus length and ownership.
- `AudioBlock`: timing and phoneme metadata for generated audio blocks.

Important handlers:

- `auth.go`: registration, login, email confirmation, password reset.
- `book.go`: create books from text/file/public-book, parse blocks, update
  versions, access checks.
- `queue.go`: queue book audio and report queue status.
- `worker.go`: worker registration, polling, status updates, audio upload.
- `textAudio.go`: result and audio-serving endpoints.
- `settings.go`: user settings.

Worker endpoints:

- `POST /api/worker/register`: register worker with admin/service auth token.
- `GET /api/worker/text`: claim next queued request.
- `POST /api/worker/status`: update queue progress.
- `POST /api/worker/audio/:hash_id`: upload generated audio.

Notes and cautions:

- `RequestBlockAudio` and `GetWorkerFile` currently call `log.Fatal` and are not
  production-ready.
- The backend currently uses SQLite and local disk audio storage.
- Generated Swagger docs feed the Angular OpenAPI client. When backend DTOs or
  routes change, regenerate docs and then regenerate the frontend client.
- Be careful with block ordering. `BlockOrder` is authoritative for playback and
  processing order, not database row order.
- Preserve access rules: owned books require owner auth; guest books use guest
  tokens; future public-domain books need explicit public/private semantics.

Useful commands:

```sh
cd nikaudio-be
nix develop
go run .
go test ./...
```

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

- `create-book`: text/file book creation flow.
- `book-editor`: block editing and book version update flow.
- `books-list`: user book list.
- `audio-requests`: queued/processed request list.
- `audio-player`: result playback.
- `audio-player/audio-playback.service.ts`: playback state/service logic.
- `block-*` and `audioblock-*`: block display and virtual scrolling helpers.
- `services/auth.service.ts`: frontend auth state.
- `interceptors/error.interceptor.ts`: redirects on auth/server errors.
- `core/api`: generated OpenAPI Angular client.

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
  milliseconds, and phoneme/foname content so the backend can build `AudioBlock`
  rows.

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
go run .

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
