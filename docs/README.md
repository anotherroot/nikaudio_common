# Librofono / Nikaudio — project docs

Cross-repo documentation for the whole workspace (all five repos). Read in order for a
full picture, or jump to what you need:

| Doc | What it answers |
| --- | --- |
| [001-vision.md](001-vision.md) | Why this exists: product goals, economics, privacy promises, why block-centric |
| [002-features.md](002-features.md) | What the product does today, area by area |
| [003-architecture.md](003-architecture.md) | Repos, system diagram, pipeline, API surface, auth, deploy |
| [004-data-model.md](004-data-model.md) | Every entity, relationships, access rules, hard invariants |
| [005-development.md](005-development.md) | Running/testing each repo, cross-repo workflows, conventions, dev log |
| [006-roadmap.md](006-roadmap.md) | In progress, planned, rough edges |

Related sources of truth:

- `CLAUDE.md` (workspace root, canonical copy in this repo) — condensed agent guide.
- `devlog/DEVLOG.md` — fine-grained, dated record of features and decisions.
- Swagger (`http://localhost:3030/swagger/index.html`) — the live API contract.

Keep these docs current: when a feature ships or an architectural decision changes,
update the affected doc in the same breath as the devlog entry.
