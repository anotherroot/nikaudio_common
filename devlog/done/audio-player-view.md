# Audio Player view (transport, seek, follow, per-block progress)

**Goal:** Turn the stub `/audio-player/:hash` into a real listening experience: a modern
floating transport bar (play/pause, book progress bar with click-seek, ±10s, ±paragraph),
click-a-block-to-play, current-block highlight, auto-scroll that follows playback, and a
minimal per-block progress fill.

## Decisions

- **Keep the existing paginated-chunk mechanism** (windowed audio via `/audio-chunk` +
  windowed blocks via `/result`), not whole-file streaming and not a full MSE rewrite.
- Model everything in the **absolute-ms book timeline**: each block carries absolute
  `start_ms`/`end_ms`; the result carries whole-book `length_ms`/`total_blocks`. A chunk's
  media clock is 0-based, so `absMs = chunkStartMs + audio.currentTime*1000`
  (`chunkStartMs = firstChunkBlock.start_ms`). Verified empirically: the ffmpeg slice reports
  `start_time=0` and `duration ≈ window span`.
- **Next/prev paragraph = next/prev block** (any type).
- v1 accepts a brief **chunk-boundary reload gap** (softened with a 30-block window); MSE
  gapless streaming is a future upgrade.

## Implementation

- **nikaudio-be:** `ResultResponse` gains `offset` (the resolved block offset), set in the
  `Result` handler for both the plain and `is_timestamp` branches. This is the one thing the
  frontend needs to align the audio chunk to the text window after a timestamp seek, since
  blocks expose no absolute index. Swagger regenerated.
- **nikaudio-web** (`src/app/audio/**`, client regenerated for `DtoResultResponse.offset`):
  - `audio-playback.service` wraps the `<audio>` (chunk-relative clock, `seekSec`, `loadChunk`,
    ended-handler).
  - `audio-player.service` = windowed **dual model** (text blocks deduped by id + current audio
    chunk) with `load`/`seekToMs`/`seekToBlock`/`nudge`/`step`/`loadMoreText`/
    `loadPreviousText`/`advanceAudioChunk` and derived signals (`absMs`, `currentBlockIndex`,
    `bookProgress`, `blockProgress`).
  - new `audio-transport.component` (floating bottom bar); `audio-block` current highlight +
    intra-block fill + played dimming; `audio-player.component` wires it and auto-scrolls to
    the playing block via the shared virtual-scroll viewport.

## Verification

- BE: `gofmt`/`go vet`/`go build`/`make swagger-check` clean.
- FE: `ng build`, `ng lint`, `prettier --check`, 84 unit tests pass.
- Chunk time-base confirmed against the real audio file (ffprobe: 0-based, duration matches).
- Headless UI smoke (faked JSON + a real sliced audio blob): play advances the clock, block
  highlight + fill track playback, in-chunk block click seeks with no network call, and a
  progress-bar seek to 80% fires `result is_timestamp offset=59` + matching `chunk offset=59`,
  reloading blocks and audio from that position.

## Remaining / follow-ups

- Real-stack manual pass on a private book (needs auth): the headless smoke used synthetic
  windows against a real audio slice.
- Possible polish: gapless MSE, centering the followed block, revisit played-block dimming.

## 2026-07-02 — Implemented FE + tiny BE offset echo, verified locally

Built on the existing chunk endpoints. Only backend change was echoing the resolved `offset`
so the frontend can fetch the audio chunk matching a timestamp-seeked text window.
