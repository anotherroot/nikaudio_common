# Pronunciation Info Panel And Builder

Goal: make Kokoro/Misaki pronunciation editing easier in the book editor by expanding the help
dialog into a usable reference and adding a phoneme-token builder for individual rows.

Decisions:

- Keep the Misaki English phone list as frontend static data for the currently supported language.
- Builder edits local book/block pronunciation row state only; the existing pronunciation Save
  buttons remain responsible for backend persistence.
- Hide builder mutation actions in readonly versions.

## 2026-07-03 — Reference panel and row builder

Added a static, paraphrased Misaki English phoneme reference with grouped shared, American-only, and
British-only tokens plus source link. Reworked the pronunciation help dialog into a wider scrollable
reference panel, and added a pronunciation builder dialog available from book and block rows as well
as new-entry actions. Builder token clicks insert at the current pronunciation cursor, and tests cover
help content, book/block row saves, cursor insertion, and readonly rendering.
