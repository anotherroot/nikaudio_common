# Sample Request Pipeline (multi-block audio samples)

**Goal:** Let users generate an audio *sample* from the book editor for one selected block
**or** several multi-selected blocks (previously only a single block), queued and processed
like a book and playable in the audio player, clearly marked as a sample.

## Decisions

- **Reuse the existing `block` request type** for 1..N blocks — no new enum, no DB migration
  (`request_type` is free text, `block_id` already nullable, multi-block content lives in
  `BlockSnapshot`s).
- Selected blocks are snapshotted in **book reading order** (`BlockOrder`), not click order.
- **"Clear it's a sample":** any non-`book` request is shown as **"Sample"** in the UI
  (requests-list label + purple badge in the player). `request_type` stays `"block"` internally.
- **No worker changes.** Everything downstream of `BlockSnapshot` is already type-agnostic:
  worker payload (`workerjobs/claim.go`), `dummy_worker.py`, and result playback
  (`audioresults/result.go`, `audioqueries`) all operate on ordered snapshots.

## Implementation

- **nikaudio-be**
  - `dto.BlocksQueueRequest { block_ids }`; added `request_type` to `dto.ResultResponse`.
  - `audioqueue.RequestBlocksAudioContext` (in `block_audio.go`): filters `BlockOrder` to the
    selected IDs (orders + validates membership), snapshots them, creates the queue row.
  - `QueueHandler.RequestBlocksAudio` + route `POST /api/queue/blocks/:version_id`.
  - `textAudio.go` result now returns `RequestType`; `audiorequests.GetOwnedRequestSourceContext`
    returns ordered snapshot blocks for `block` requests.
  - Tests: `block_audio_test.go` (ordering/snapshots/queue, empty + out-of-version rejection),
    handler tests for invalid version id and empty selection. Swagger regenerated.
- **nikaudio-web**
  - Regenerated API client (`queueBlocksVersionIdPost`, `DtoResultResponse.request_type`).
  - `book-editor.service.submitSample(versionId, blockIds)`; component `submitSample()` collects
    single/mass selection, keeps only persisted numeric IDs, guards on dirty/unsaved.
  - "Generate Sample" buttons in single-block actions and Mass Actions; player "Sample" badge;
    requests-list label `block` → "Sample".

## Verification done

- Backend: `make fmt-check`, `go vet`, package tests, `make swagger-check` all pass.
- Frontend: `ng build`, eslint, `prettier --check`, 84 unit tests pass.
- Headless-browser smoke (faked API): player shows the **Sample** badge next to the title;
  requests list shows **Sample** vs **Book**.

## Remaining (real-stack E2E, on the user's machine)

Run postgres + backend + `dummy_worker.py`: select 1 block then several blocks → Generate
Sample; drain the queue; open each from `/audio-requests` and confirm playback + Sample badge,
blocks in book order.

## 2026-07-01 — Implemented end to end (BE + FE), verified locally

Built the multi-block sample path reusing the `block` request type. No migration and no worker
changes were needed because the snapshot-based pipeline was already type-agnostic. Kept the
legacy single-block `/queue/block/:block_id` endpoint for compatibility; the editor now uses the
new `/queue/blocks/:version_id` endpoint for both single and multi selection.
