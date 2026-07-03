---
name: devlog
description: Maintain the cross-repo Nikaudio dev log in nikaudio-common/devlog/. Use when starting a new feature/task, recording a decision or progress, or changing a feature's status (doing/waiting/done). Trigger phrases include "log this", "start a feature", "mark X done", "update the devlog", or when finishing meaningful work that future sessions should know about.
---

# Nikaudio dev log

The dev log lives in `nikaudio-common/devlog/` and records **what we work on and why** —
context that isn't obvious from code or git history. It is intentionally **cross-repo**:
a feature often spans `nikaudio-web`, `nikaudio-be`, and `nikaudio-worker`, but its log
always lives here.

## Layout

- `DEVLOG.md` — project index. One bullet per feature, grouped under `## Doing`,
  `## Waiting`, `## Done`. Each bullet links the feature file and gives a one-line summary.
- `doing/`, `waiting/`, `done/` — one Markdown file per feature, named `<feature-slug>.md`
  (kebab-case).

## Feature file format

```markdown
# <Feature Title>

**Status:** <doing|waiting|done> · **Area:** `<repo>` (<optional sub-area>)

## Goal

<1–3 sentences: what and why.>

## Decisions

- <key choices and their rationale — the stuff worth remembering later>

## Log

## YYYY-MM-DD — <short what/why>

- <what changed and why. Record decisions/rationale, not a restatement of the diff.>
```

The `## Log` holds dated entries in **reverse-chronological order** (newest on top, directly
under the `## Log` heading). Each entry is `## YYYY-MM-DD — <summary>`.

## DEVLOG.md bullet format

```markdown
- [<Feature Title>](<folder>/<slug>.md)
  — <one-line summary>.
```

Place the bullet under the section matching the feature's current status.

## Workflows

**Get the date first.** Always run `date +%F` for the real current date — do not guess.

### Start a new feature
1. Create `nikaudio-common/devlog/doing/<slug>.md` using the feature-file format (fill Goal,
   Decisions, and an initial dated Log entry describing the plan).
2. Add a bullet under `## Doing` in `DEVLOG.md`.

### Record progress or a decision
1. Prepend a new `## YYYY-MM-DD — <summary>` entry under `## Log` in the feature file
   (newest first). If there's already an entry for today, append to it or add a sibling —
   don't rewrite prior entries.
2. If the summary in `DEVLOG.md` is now stale, update that one line too.

### Change status (doing ↔ waiting ↔ done)
1. Update the `**Status:**` line in the feature file.
2. Add a dated Log entry noting the transition and why (e.g. blocked on X, or completed).
3. **Move the file** to the matching folder (`doing/`, `waiting/`, `done/`).
4. Move (and, if needed, reword) its bullet to the matching section in `DEVLOG.md`.

## Rules

- Prefer decisions and rationale over restating code changes.
- Keep `DEVLOG.md` in sync with the folders — a file's location, its `**Status:**` line, and
  its `DEVLOG.md` section must always agree.
- Since `nikaudio-common` is its own git repo, `git -C nikaudio-common add` the changed
  devlog files if the user wants them staged. Only commit when asked.
</content>
