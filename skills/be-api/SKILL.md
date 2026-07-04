---
name: be-api
description: Call the Nikaudio backend API from the CLI — auth cookie flows, guest tokens, worker-simulation flow, queue/audio recipes, and direct DB access. Use when testing or debugging backend endpoints, inspecting queue/audio state, or simulating the TTS worker.
---

# Nikaudio backend API from the CLI

Base URL: `http://localhost:3030/api` · Swagger UI: `http://localhost:3030/swagger/index.html`
· OpenAPI JSON: `http://localhost:3030/swagger/doc.json` (grep this for exact request/response
shapes instead of reading handler code).

The backend runs under air in tmux pane **`Nikaudio BE:0.1`** — after any request you can see
its log lines with:

```sh
tmux capture-pane -p -t 'Nikaudio BE:0.1' -S -60
```

Build errors after BE edits: `nikaudio-be/tmp/build-errors.log` (also visible in that pane).
CORS only affects browsers — curl needs no Origin header.

## Auth model

| Actor | Mechanism | How in curl |
| --- | --- | --- |
| Registered user | `session_id` cookie | cookie jar (`-c`/`-b`) |
| Guest | `guest_token` cookie (set by first book create) | same jar |
| Worker | `Authorization: Bearer <token>` | shared token to register → per-worker token |
| Admin | user with `role='admin'` | same cookie jar |

Use one jar file per identity, e.g. `/tmp/na-user.jar`, `/tmp/na-guest.jar`.

## User session

```sh
# Login (JSON body) — writes session_id cookie to the jar
curl -s -c /tmp/na-user.jar -H 'Content-Type: application/json' \
  -d '{"email":"EMAIL","password":"PASSWORD"}' http://localhost:3030/api/login

# Verify (returns email, is_admin)
curl -s -b /tmp/na-user.jar http://localhost:3030/api/auth/check
```

### Create a throwaway dev account (no mail server needed)

Register, then pull the confirm token straight from the DB:

```sh
curl -s -H 'Content-Type: application/json' \
  -d '{"email":"dev+test1@example.com","password":"devpass123"}' \
  http://localhost:3030/api/register

TOKEN=$(docker compose -f nikaudio-be/docker-compose.yml exec -T postgres \
  psql -U nikaudio -d nikaudio -tA \
  -c "SELECT confirm_token FROM users WHERE email='dev+test1@example.com'")

curl -s -H 'Content-Type: application/json' -d "{\"token\":\"$TOKEN\"}" \
  http://localhost:3030/api/confirm-email
# then login as above
```

Promote to admin: `UPDATE users SET role='admin' WHERE email='...';` via the same psql.

## Guest flow

`POST /book/from-text` without a session creates a guest book and **sets the `guest_token`
cookie in the response** — capture it with `-c`:

```sh
curl -s -c /tmp/na-guest.jar -F 'text=Hello world. Second paragraph.' \
  -F 'book_name=Guest test' http://localhost:3030/api/book/from-text
```

Guests are limited to 1000 chars / 10 blocks; file upload is auth-only. Reuse the jar (`-b`)
for all subsequent guest requests on that book.

## Books

```sh
# Create from text (multipart form, NOT JSON): fields text, book_name, file (auth only)
curl -s -b /tmp/na-user.jar -F 'book_name=My book' -F 'file=@/path/book.epub' \
  http://localhost:3030/api/book/from-file
# → {hash_id, book_id, book_version_id, block_count, is_guest}

curl -s -b /tmp/na-user.jar http://localhost:3030/api/books
curl -s -b /tmp/na-user.jar 'http://localhost:3030/api/book/version/VERSION_ID?page=0'
curl -s -b /tmp/na-user.jar 'http://localhost:3030/api/book/version/VERSION_ID/search?q=word'
```

Block mutations go through `PUT /book/version/:version_id` (`UpdateBookRequest`: updated
blocks, new blocks with `local_id`, deleted IDs, `block_order` of `{id|local_id}` items) —
check the Swagger JSON for the exact shape before crafting one.

## Queue & audio

```sh
# Queue a whole version (voice_id is a string key, may be empty for version default)
curl -s -b /tmp/na-user.jar -H 'Content-Type: application/json' -d '{"voice_id":""}' \
  http://localhost:3030/api/queue/book/VERSION_ID
# → {queue_id, audio_request_id, hash_id, status, type}

# Queue selected blocks as a sample
curl -s -b /tmp/na-user.jar -H 'Content-Type: application/json' \
  -d '{"block_ids":[1,2,3]}' http://localhost:3030/api/queue/blocks/VERSION_ID

curl -s -b /tmp/na-user.jar http://localhost:3030/api/queue/status/QUEUE_ID
curl -s -b /tmp/na-user.jar http://localhost:3030/api/result/HASH_ID          # metadata + blocks
curl -s -b /tmp/na-user.jar -o /tmp/out.m4b http://localhost:3030/api/audio/HASH_ID
curl -s -b /tmp/na-user.jar http://localhost:3030/api/audio-requests
```

Note: `POST /queue/block/:block_id` and `GET /worker/file/:audio_id` are 501 stubs.

## Simulating the worker

The real dummy client lives at `nikaudio-be/dummy_worker` — prefer running it for full
pipeline tests. Manual protocol:

```sh
WAT=$(grep '^WORKER_AUTH_TOKEN=' nikaudio-be/.env | cut -d= -f2)

# 1. Register (shared token) → per-worker bearer token
WT=$(curl -s -H "Authorization: Bearer $WAT" -H 'Content-Type: application/json' \
  -d '{"worker_type":"free"}' http://localhost:3030/api/worker/register | \
  python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')

# 2. Claim top job — 204 = queue empty; 200 body: {queue_id, request_id, hash_id,
#    request_type, voice_id, lang_id, blocks:[{id, content, pronunciations, voice_key, lang_key, type}]}
curl -s -i -H "Authorization: Bearer $WT" http://localhost:3030/api/worker/text

# 3. Report progress
curl -s -H "Authorization: Bearer $WT" -H 'Content-Type: application/json' \
  -d '{"queue_id":QID,"progress":50,"status":"processing"}' \
  http://localhost:3030/api/worker/status

# 4. Upload result (multipart): file, length_ms, block_data =
#    JSON [{"block_id":<snapshot block id>,"end_ms":N,"fonames":"..."}, ...]
curl -s -H "Authorization: Bearer $WT" -F 'file=@/tmp/out.m4b' -F 'length_ms=12345' \
  -F 'block_data=[{"block_id":1,"end_ms":5000,"fonames":"..."}]' \
  http://localhost:3030/api/worker/audio/HASH_ID
```

Block IDs in `block_data` must match the claimed payload's block IDs (they're snapshot-backed;
the backend validates them). Claiming a job flips the queue row to `processing` and sets
`locked_at` — if you claim and never finish, the row stays locked until crash recovery.

## Direct DB access

```sh
docker compose -f nikaudio-be/docker-compose.yml exec -T postgres \
  psql -U nikaudio -d nikaudio -c "SQL"
```

Handy queries:

```sql
SELECT id,status,progress,worker_id,locked_at FROM queues ORDER BY id DESC LIMIT 5;
SELECT id,hash_id,request_type,processed,public_book_id FROM audio_requests ORDER BY id DESC LIMIT 5;
SELECT id,email,role,is_confirmed FROM users;
SELECT id,name,visibility,user_id,source_public_book_id FROM books ORDER BY id DESC LIMIT 10;
```

Prefer SELECTs; for mutations, say what you're about to change first. Table names are GORM
plurals with snake_case columns; soft deletes mean `deleted_at IS NULL` matters on most tables.
