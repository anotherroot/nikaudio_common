# 006 — Roadmap

Direction and status. The authoritative, fine-grained record is the dev log
(`nikaudio-common/devlog/DEVLOG.md`); this file is the coarse map. Update it when a
milestone lands or plans change (dated notes help).

## In progress (mid-2026)

- **UI revamp + dark mode** — coherent look via semantic color tokens + class-based dark
  mode; retire the gradient-era screens while keeping the editor/player design language.
- **Public-domain books** — all planned phases (models, disable-block, admin ingest + UI,
  browse/suggest, make-your-version/text-lock/make-private, versions + voting,
  create-book-from-audiobook) are implemented; remaining: a manual end-to-end pass with
  the running stack before moving to done.
- **Landing page follow-ups** — the Librofono site is built (in `nikaudio-landing`);
  still pending: register the real domain (placeholder `librofono.example`) and do the
  first deploy.

## Planned

- **Block-level audiobook patching** — regenerate selected blocks and splice them into an
  existing audiobook. The data model is already prepared for this
  (`AudioBlock.BlockSnapshotID` + per-block timing); the generation/splicing pipeline is
  not built. The stubbed `POST /queue/block/:block_id` and `GET /worker/file/:audio_id`
  (both 501) are the API footholds.
- **Production worker daemon** — turn `worker.py` from a local file script into the
  polling daemon (claim → process snapshots → status → upload `.m4b` + block metadata),
  keeping the ~200-phoneme chunking and block timing.
- **Shared pronunciation dictionaries** — community-maintained term → phoneme mappings,
  seeded/improved by user corrections on shared books.
- **Pronunciation improvement from corrections** — learn from per-block fixes users make.
- **Paid fast path** — near-cost serverless GPU for private jobs that skip the free
  queue; same worker protocol.
- **Production storage & serving** — local-disk filestore is dev-only; decide on
  concurrency/backup/serving (object storage, range requests, CDN?) before real load.

## Known rough edges

- Backend tests are sparse/placeholder outside the recently-tested services.
- SQLite (tests) and local-disk storage are dev-only.
- Some routes are registered but 501 (block audio queueing, worker file download).
- The domain isn't registered; the landing site isn't deployed.

## Done highlights

See `devlog/done/` for the full list with rationale. Recent landmarks: audio player
listening UI, shared virtual-scroll engine, sample request pipeline, block toolbar +
command palette + undo/redo, pronunciation panel + builder, landing page build-out, and
the public-domain catalog end-to-end.
