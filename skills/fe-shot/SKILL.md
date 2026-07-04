---
name: fe-shot
description: Take headless screenshots of the running Nikaudio/Librofono frontend (light or dark mode, any route/viewport) for visual verification of UI work. Use whenever CSS/layout/theme changes need to be seen, or to check what a page actually renders.
---

# Screenshot the running frontend

The FE dev server runs in tmux pane **`Nikaudio FE - web:0.1`** and serves
`http://localhost:3031`. It rebuilds on file save — check the pane for
"Application bundle generation complete" / compile errors before screenshotting:

```sh
tmux capture-pane -p -t 'Nikaudio FE - web:0.1' -S -30
```

**Always use `http://localhost:3031`, never `127.0.0.1:3031`** — the backend CORS
allowlist matches the `localhost` origin only; the wrong origin redirects the app to
`/unreachable`.

## Toolchain paths (Nix; not on bare PATH)

```sh
CHROMIUM=/nix/store/dzkgn9gz6snw9gb01h4jqfysm64a4m2k-chromium-139.0.7258.127/bin/chromium
NODE22=/nix/store/6s9qrnf23whlvphz6p5fkczfhpaj0zya-nodejs-22.22.2/bin/node
```

If a store path is gone (GC'd), find replacements:
`ls -d /nix/store/*chromium*/bin/chromium /nix/store/*nodejs*/bin/node`.
The harness needs Node **22+** (global `WebSocket`).

## Light-mode shot (simplest)

```sh
"$CHROMIUM" --headless --screenshot=/tmp/shot.png --window-size=1600,900 \
  --hide-scrollbars --virtual-time-budget=8000 'http://localhost:3031/books'
```

## Any mode, via the CDP harness (`shot.mjs` in this skill dir)

Dark mode needs CDP media emulation (`prefers-color-scheme: dark` → the app's `.dark`
class), which plain `--screenshot` can't do:

```sh
CHROME_BIN="$CHROMIUM" "$NODE22" <this-skill-dir>/shot.mjs \
  'http://localhost:3031/books' /tmp/books-dark.png --dark --width=1600 --height=900
```

Options: `--dark`, `--width=N`, `--height=N`, `--wait=ms` (settle time after load,
default 2500 — raise it for data-heavy pages like the editor/player).

Then **Read the PNG** to actually look at it.

## Tips

- Routes needing auth render the login redirect — to screenshot authed pages, first check
  what state the page needs; guest/anonymous pages (`/`, `/login`, `/public-books`) are
  safest. (Authed screenshots would need a session cookie injected via CDP —
  `Network.setCookie` before navigate — extend shot.mjs if needed.)
- Take light + dark pairs when verifying theme work (tokens: see auto-memory
  `nikaudio-theme-tokens`).
- Screenshot both before and after a change when the diff matters.
- Console errors: the FE pane only shows build output; runtime JS errors need CDP
  (`Runtime.consoleAPICalled`) — extend shot.mjs if a page renders blank.
