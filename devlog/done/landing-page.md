# Landing Page (Librofono brand, static site + deploy/nginx wiring)

**Status:** done · **Area:** `nikaudio-landing` (new sibling repo) + `nikaudio-common` (deploy/nginx)

## Goal

Public SEO landing page for the app: a fast, hand-written static one-pager on the root
domain, with the app itself living on the `app.` subdomain. Covers the page (new sibling
repo `nikaudio-landing`) plus the deploy script and nginx wiring in this repo.

## Decisions

- **Public brand name: Librofono** (chosen 2026-07-04 over "Librefono") — book-anchored
  ("libro") beats free-anchored; "free" stays in the headline copy instead of the name.
- Domains `librofono.com`/`.org` and defensively `librefono.com`/`.app`/`.org` verified
  RDAP-unregistered as of 2026-07-04 — should be registered soon.
- Real domain not bought yet → placeholder `librofono.example` used everywhere (landing at
  root, app at `app.librofono.example`). The placeholder is greppable; the one-command sed
  swap is documented in the landing README.
- Hand-written static one-pager — no framework, no build step, no external requests, system
  fonts — chosen for performance/SEO.
- New sibling repo `nikaudio-landing` (dev naming kept for repo dirs; the brand name is
  user-facing only).
- Deploy = new `scripts/deploy_landing.sh` (config-driven rsync, mirrors `deploy_v2.sh`) +
  `config/nginx.landing.config.example` (root domain serves the static site; `app.`
  subdomain serves the Angular build with `/api` proxied to `:3030` — same-origin, so no
  CORS headers).
- SEO structured data: JSON-LD `WebSite` + `SoftwareApplication` (price 0) + `FAQPage`.

## Log

## 2026-07-04 — Done: site built, verified, committed

- `nikaudio-landing` repo created and committed (`d4e4804` on `main`): hand-written
  `index.html` + single CSS + 25-line decorative JS, hand-crafted SVG logo/hero art,
  ImageMagick-generated favicon.ico/apple-touch-icon/og-image (og-image intentionally has
  no domain text so the future domain swap needs no regen), robots.txt/sitemap.xml, local
  dev server (`scripts/serve.mjs`, :3032, nix-store node), README with domain-swap command.
- Independently verified end-to-end: all referenced assets 200, exactly one `h1`, JSON-LD
  parses (WebSite/SoftwareApplication/FAQPage; FAQ text matches HTML), zero external
  requests, 27.5 KB / 6 requests total, no console errors, works with JS disabled,
  headless-Chromium screenshots clean at 1440px and 500px (scroll-reveal needed
  `--virtual-time-budget` to settle — cosmetic only).
- nginx example fix during review: `robots.txt`/`sitemap.xml` were caught by the
  1y-immutable regex; now short-cached (1h must-revalidate).
- Remaining follow-ups (not part of this feature): register `librofono.com`/`.org`
  (+ defensive `librefono.*`) — RDAP-free as of 2026-07-04; run the sed domain swap; first
  real deploy via `scripts/deploy_landing.sh` + nginx config install.

## 2026-07-04 — Deploy/nginx wiring in nikaudio-common

- Added `scripts/deploy_landing.sh`: same structure/style as `deploy_v2.sh` (sources
  `config/deploy/dev.config`, colored print helpers, SSH connection test, sudo
  mkdir/chown dance), validates the landing dir + `index.html`, then
  `rsync -av --delete` (excluding `.git`, `scripts/`, `README.md`, `.gitignore`) to
  `LANDING_SERVER_PATH` and chowns to `nginx:nginx`. No build step — pure static files.
- Added `LANDING_PROJECT_PATH`/`LANDING_SERVER_PATH` (default `/var/www/nikaudio-landing`)
  to all `config/deploy/*.config` files.
- Added `config/nginx.landing.config.example`: `www` → root redirect, root-domain static
  block (`try_files $uri =404`, short-cached `index.html`, 1y immutable assets), and the
  `app.` subdomain block (Angular SPA fallback + `/api/` proxy to `localhost:3030`,
  dropping the old dev-only CORS block).
- Landing site itself is being built in parallel in `../nikaudio-landing`.
