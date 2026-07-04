# Project Docs

Goal: a cross-repo `docs/` folder in `nikaudio-common` giving the full project picture —
vision, features, architecture, data model, development, roadmap — so agents/humans have a
richer source than the condensed `CLAUDE.md`.

Decisions:

- Numbered reading-order files (`001-vision.md` … `006-roadmap.md`) + a `README.md` index.
- Docs live in `nikaudio-common` next to the devlog, since both are cross-repo. Devlog stays
  the fine-grained dated record; docs are the coarse durable picture; `CLAUDE.md` stays the
  condensed agent guide and now links to the docs.
- Content grounded in the current code (models, router, frontend routes) and devlog, not just
  the old guide — so it includes public-domain catalog, pronunciations, disable-block, the
  landing repo, etc.

## 2026-07-04 — Initial docs + CLAUDE.md link

- Wrote `docs/README.md` (index) + `001-vision` (Librofono goals, economics, privacy,
  block-centric rationale), `002-features` (current feature inventory incl. 501 stubs),
  `003-architecture` (5 repos, system diagram, pipeline, API route groups, auth table,
  deploy), `004-data-model` (all models incl. `PublicBook`/`BookSuggestion`/
  `AudioVersionVote`, access rules, hard invariants), `005-development` (per-repo commands,
  cross-repo workflows, conventions), `006-roadmap` (doing/planned/rough edges).
- Updated both `CLAUDE.md` copies (root + this repo, kept byte-identical): four → five repos
  (added `nikaudio-landing`), plus a "Project documentation" pointer to `docs/`.
