# Agent Dev Tooling

**Status:** done · **Area:** `nikaudio-common` (skills + agent guide)

## Goal

Give coding agents first-class access to the always-running dev stack: read/verify the
air + `npm start` hot rebuilds, query Postgres directly, exercise the API like Postman,
and screenshot the FE for visual verification — without re-deriving any of it per session.

## Decisions

- **Observe, don't own**: the user keeps running BE/FE in their existing tmux sessions
  (`Nikaudio BE:0.1` = air, `Nikaudio FE - web:0.1` = npm). Agents read panes via
  `tmux capture-pane` and may `send-keys`, instead of spawning duplicate servers that
  would fight over ports and die with the agent session.
- **No MCP servers**: psql-in-docker and curl cover DB + API access with zero context
  overhead; the one MCP worth considering later is Chrome DevTools (for interactive FE
  control), not Postgres.
- **Skills live canonically in `nikaudio-common/skills/`** (tracked, cross-repo like the
  devlog) and are **symlinked** into the workspace `.claude/skills/` — verified that
  Claude Code loads skills through symlinks.
- `fe-shot` freezes the previously session-scratchpad-only CDP screenshot harness into a
  permanent `shot.mjs` (Node 22 global WebSocket; dark mode via prefers-color-scheme
  emulation → the app's `.dark` class).
- `be-api` documents the fiddly auth bits agents kept re-deriving: cookie jars for
  session/guest (`session_id`/`guest_token` cookies), throwaway dev accounts by reading
  `confirm_token` from the DB (no mail server), and the worker bearer-token protocol.

## Log

## 2026-07-04 — Skills built, tested live, runbook linked

- Added `skills/be-api/SKILL.md` (auth flows, guest/queue/audio recipes, worker-protocol
  simulation, psql one-liners) and `skills/fe-shot/` (`SKILL.md` + `shot.mjs` CDP
  harness). Symlinked both into `.claude/skills/`; they registered in-session.
- Tested against the running stack: guest book create with cookie capture (then removed
  the test row via psql), queue-table query, and light+dark screenshots of
  `/public-books` (dark emulation confirmed working).
- Runbook: new "Live dev environment" section in `CLAUDE.md` (both copies, kept
  identical) — tmux pane names, rebuild-verification rule after BE/FE edits, psql
  one-liner, skill pointers — plus a fuller table in `docs/005-development.md`.
