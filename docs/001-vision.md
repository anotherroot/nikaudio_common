# 001 — Vision

## What this project is

**Librofono** (dev codename: *Nikaudio*) turns books — EPUBs, plain text, pasted text —
into high-quality audiobooks using the open-source **Kokoro** TTS model. The public brand
is Librofono; "Nikaudio" appears only in repo names, code, and internal docs. The domain is
not yet registered (placeholder: `librofono.example`).

## Product goals

1. **Cheap, high-quality AI audiobook generation.** Commercial audiobook TTS is expensive;
   Kokoro on commodity GPUs makes near-free generation possible. Users upload or paste a
   book, tweak it in a block editor, and get an `.m4b` with per-paragraph timing.
2. **A public repository of free public-domain audiobooks.** Once a public-domain book has
   been processed, its audio becomes a shared asset: anyone can listen, and the community
   ranks competing audio versions by like/dislike. Processing effort compounds instead of
   being repeated per user.

## Economic model

- **Free path** — a standing GPU worker (RTX 3060-class, always on). Users queue when
  demand exceeds capacity. Good enough for public-domain work and patient users.
- **Paid fast path (planned)** — near-cost serverless GPU for private jobs that skip the
  queue.

## Privacy boundaries

- **Public-domain catalog books** and audio generated from them are shared assets.
- **User-uploaded private books** stay private to their owner — always.
- **Guest books** exist without an account, protected by a guest token, and expire.

These boundaries are a core product promise; every feature must respect them
(see [004-data-model.md](004-data-model.md) for how visibility is modeled).

## Why block-centric

Everything is built around **ordered blocks** (usually paragraphs) rather than opaque
audio files. Blocks carry content, type (paragraph/chapter title), pronunciations, voice,
and language; generated audio keeps per-block timing and phoneme metadata. This enables:

- playback that follows the text (highlight, click-to-seek, search),
- pronunciation work at the exact spot a word is spoken,
- **block-level patching** (planned): regenerate only the blocks a user corrected and
  splice them into an existing audiobook instead of re-rendering the whole book,
- community pronunciation improvement: corrections made on shared books can feed shared
  pronunciation dictionaries (planned).

## Longer-term direction

- Grow the public-domain catalog (admin-curated, user-suggested).
- Shared pronunciation dictionaries + learning from user corrections.
- Block-level audiobook patching.
- Paid serverless GPU fast path.

See [006-roadmap.md](006-roadmap.md) for current status of each.
