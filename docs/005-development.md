# 005 — Development

How to run, test, and change the system. Each repo has a Nix flake — enter it with
`nix develop` (node/go/python may not be on the bare PATH).

## Live dev environment (usual state)

The whole stack normally runs continuously in tmux; agents/tools should observe it rather
than start second instances (the ports would clash):

| What | Where | Notes |
| --- | --- | --- |
| Backend via `air` | tmux pane `Nikaudio BE:0.1` | Rebuilds on save; request logs live here; compile errors also in `nikaudio-be/tmp/build-errors.log` |
| Frontend via `npm start` | tmux pane `Nikaudio FE - web:0.1` | Rebuilds on save; serves `http://localhost:3031` |
| Postgres 16 | docker compose (`nikaudio-be/docker-compose.yml`) | `exec -T postgres psql -U nikaudio -d nikaudio` for direct SQL |

Read a pane: `tmux capture-pane -p -t 'Nikaudio BE:0.1' -S -60`. Send input:
`tmux send-keys -t 'Nikaudio BE:0.1' ...`. **After editing BE/FE code, check the relevant
pane (or `build-errors.log`) to confirm the hot rebuild succeeded** — a broken build
otherwise fails silently from the editor's perspective.

Agent skills wrapping this environment live in `nikaudio-common/skills/` (symlinked into
the workspace `.claude/skills/`):

- **`be-api`** — curl recipes for the whole API: session/guest cookie jars, throwaway dev
  accounts (confirm token via DB), queue/audio flows, worker-protocol simulation, psql
  one-liners.
- **`fe-shot`** — headless Chromium screenshots of the running FE (light + dark via a CDP
  harness, `shot.mjs`), for visual verification of UI work.

## Backend (`nikaudio-be`)

```sh
cd nikaudio-be && nix develop
docker compose up -d postgres     # runtime DB
go run ./cmd/api                  # or: air (hot reload)
make fmt-check lint test swagger-check
```

- Serves on `:3030`; Swagger UI at `http://localhost:3030/swagger/index.html`.
- Env (defaults match `docker-compose.yml`): `DB_DRIVER=postgres`, `DB_HOST=localhost`,
  `DB_PORT=5432`, `DB_NAME=nikaudio`, `DB_USER=nikaudio`, `DB_PASSWORD=nikaudio`,
  `DB_SSL_MODE=disable`. Set `WORKER_AUTH_TOKEN` for worker registration.
- Startup runs the committed Postgres migrations in `src/db/migrations/postgres`
  (`golang-migrate`) — schema changes need a migration, not `AutoMigrate`.
- Tests: SQLite + `AutoMigrate` for throwaway unit tests only. Postgres-dependent
  integration tests (queue claiming etc.) are gated by `TEST_DATABASE_DSN` and
  create/drop their own schemas — only set it when you mean to run them.
- Keep Swagger annotations in sync with handlers; `make swagger-check` verifies. The
  generated `docs/` feed the frontend client.

## Frontend (`nikaudio-web`)

```sh
cd nikaudio-web && nix develop
npm install && npm start          # dev server on 127.0.0.1:3031
npm run check                     # eslint + prettier + build + test
npm run generate-api              # regen client; backend must be up on :3030
```

- `src/app/core/api` is **generated** — never hand-edit it; change backend Swagger/DTOs
  and regenerate. (Offline fallback: hand-edit the generated `dto*.ts` to match the
  backend contract, regen properly later.)
- Run `npm run check` after refactors; at minimum relevant lint/build for small edits.
- The generated `Configuration` uses `withCredentials: true` — preserve cookie creds.

## Worker (`nikaudio-worker`)

```sh
cd nikaudio-worker
nix develop .#cpu                 # onnxruntime
nix develop .#gpu                 # onnxruntime-gpu, ONNX_PROVIDER=CUDAExecutionProvider
python worker.py input/test.txt af_heart 1.0
```

- The flake downloads `kokoro-v1.0.onnx` + `voices-v1.0.bin` if missing.
- `playground*`, `old`, `bench`, `shell-for-kokoro` are experiments — no production logic
  there; don't commit generated audio/model artifacts.

## Deploy (`nikaudio-common`)

```sh
cd nikaudio-common
./scripts/deploy_v2.sh --help     # app deploy (backend + frontend)
./scripts/deploy_landing.sh       # static landing site
```

Configs in `config/deploy/{dev,prod}.config` (environment-specific, no secrets in git).

## Cross-repo workflows

**API contract change** (the most common multi-repo dance):

1. Update backend models/DTOs/handlers + Swagger annotations.
2. Regenerate Swagger docs; `make swagger-check`.
3. Start the backend on `:3030`.
4. `npm run generate-api` in `nikaudio-web`.
5. Update Angular code to the new types; build/test both sides.

**Queue/worker protocol change:**

1. Update backend DTOs + worker handlers first — keep the JSON contract explicit in
   `src/dto`.
2. Update worker parsing/upload.
3. Verify queue state transitions (`waiting`/`processing`/`done`) and crash recovery
   around `locked_at`.

## Conventions for changes

- Read the relevant subproject before editing (the workspace contains experiments); check
  `git status` per repo — the five repos are independent.
- Handlers thin, services thick (transactions/multi-table/queue logic in `src/services`).
- Reuse `src/bookblocks` for anything touching `BlockOrder`.
- Preserve the invariants in [004-data-model.md](004-data-model.md) — block
  identity/order/timing and public/private boundaries.
- Prefer small testable functions for parsing, access checks, queue transitions, and the
  worker protocol; add focused tests on meaningful behavior changes.
- Frontend: feature services own state (private writable signals, `asReadonly()` out),
  presentation components stay API-free for multi-step workflows.

## Dev log (`nikaudio-common/devlog/`)

The cross-repo record of *what* we worked on and *why* — context not recoverable from
code or git history.

- `DEVLOG.md` — index, one line per feature, grouped `Doing` / `Waiting` / `Done`.
- `doing/`, `waiting/`, `done/` — one file per feature: short goal/decisions header +
  reverse-chronological `## YYYY-MM-DD — <what/why>` entries.
- Create `doing/<slug>.md` when starting a feature (+ index link); append entries as you
  work (decisions/rationale, not diffs); move the file and update the index as status
  changes. It lives here even when the code lives in another repo.
