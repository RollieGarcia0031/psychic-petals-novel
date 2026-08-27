# TODO: Bilingual Prose Structure (`main/en` + `main/tl`)

Restructure the novel's prose directory to support an English and Tagalog version,
syncing each language to its own Firestore document with a switchable reader UI.

## Scope

- **Restructure**: `psychic-petals-novel/main/` only.
- **Untouched**: `outlines/`, `story-bible/` — remain English and serve both versions.
  Chapter numbering is the link between outline scenes and either prose version.

## Target layout

```
psychic-petals-novel/
├── outlines/          # UNTOUCHED
├── story-bible/       # UNTOUCHED
└── main/
    ├── en/episode-01/01-unlabeled-maps.md        # English moved here (git mv)
    └── tl/episode-01/01-mga-mapang-di-pinalagyan.md  # Tagalog stubs
```

Firestore mapping: `en` / legacy bare paths → `novels/psychic_petals`;
other language prefixes → `novels/psychic_petals_{lang}` (e.g., `psychic_petals_tl`).

## Tagalog chapter stubs (episode 01 — placeholder titles, revise while drafting)

| # | English | TL slug | Working title |
|---|---------|---------|---------------|
| 1 | Unlabeled Maps | `mga-mapang-di-pinalagyan` | Mga Mapang Di-Pinalagyan |
| 2 | Home | `tahanan` | Tahanan |
| 3 | Chords | `mga-chords` | Mga Chords |
| 4 | The Things He Couldn't Make | `ang-mga-hindi-niya-magawa` | Ang Mga Hindi Niya Magawa |
| 5 | Flower In The Cracks of Concrete | `bulaklak-sa-mga-bitak-ng-kongkreto` | Bulaklak sa mga Bitak ng Kongkreto |
| 6 | The Lights We Keep | `ang-mga-ilaw-na-atin` | Ang Mga Ilaw na Atin |

Each stub gets frontmatter plus a **non-empty** placeholder body (the sync script
treats empty files as deletions):

```markdown
---
title: Tahanan
episode: 1
chapter: 2
status: draft
translationOf: 1/2
---

# Tahanan

*(Draft — hindi pa tapos.)*
```

## Phase 1 — Backend (must land before any file moves)

Repo: `psychic-petals-platform/backend/`

- [ ] `scripts/sync-novel.js`
  - [ ] Extend `parseChapterPath` regex to accept all three forms:
    - `main/episode-NN/NN-slug.md` (legacy)
    - `main/en/episode-NN/NN-slug.md`
    - `main/tl/episode-NN/NN-slug.md`
  - [ ] Route languages: `en`/bare → base novel ID; other prefixes → `{id}_{lang}`
  - [ ] Group operations per resolved novel ref; run reconciliation per novel doc
    so each language self-heals independently
  - [ ] Add `--novel-id` CLI override (default `psychic_petals`)
  - [ ] Add minimal hand-rolled YAML frontmatter parser (~30 lines, no new deps):
    read `title`, `episode`, `chapter`, `status`, `translationOf`; store as chapter
    fields; fall back to H1 heading → filename slug when absent
- [ ] `utils/novelUtils.js` — parameterize hardcoded `NOVEL_ID`
- [ ] Extend `scripts/sync-novel.test.js`: all three path forms, frontmatter
  precedence, mixed en+tl run, per-novel reconciliation isolation
- [x] Update `docs/DATABASE.md` (+ add `language`, `status`, `translationOf` fields)
- [ ] `npm test` passes
- [ ] New `scripts/reset-novel.js` — database recovery tool ("nuke and rebuild")
  - [ ] Delete **everything** under `novels/{id}` (root doc + `episodes` +
    `chapters` subcollections) for each version: `psychic_petals`, `psychic_petals_tl`.
    Unlike the sync script's reconciliation (which only removes orphaned chapter
    docs), this guarantees clean state — no stale empty episodes, no leftover
    metadata fields.
  - [ ] Full rebuild: scan ALL chapter files under `main/**` across languages,
    re-parse (path regex + frontmatter), and rewrite every chapter doc; recreate
    episode docs; recalculate `totalWords` rollups per episode and novel
  - [ ] Reuse exported helpers from `sync-novel.js` (`parseChapterPath`,
    frontmatter parser, chunking, `buildNovelDocument`) instead of duplicating
  - [ ] Destructive-action guard: require explicit `--yes` flag; print a summary
    of what will be deleted (per novel doc, episode/chapter counts) before wiping;
    refuse to run without it
  - [ ] Accept `--novel-dir` (required) and `--novel-id` (default `psychic_petals`),
    consistent with `sync-novel.js`; optional `--lang` filter to reset only one
    version (e.g., `--lang tl`)
  - [ ] Tests: wipe scope (does not touch other collections/novels), full rebuild
    counts, aggregate recalculation, guard refusal without `--yes`
  - [ ] Document usage + warning that reset wipes API-managed fields (`notes`)
    in script header comment and backend README

## Phase 2 — Novel repo restructure

Repo: `psychic-petals-novel/`

- [ ] `git mv main/episode-01/*` → `main/en/episode-01/` (history preserved;
  old-path deletions + new-path additions self-heal against the dual-form regex)
- [ ] Create `main/tl/episode-01/` with the 6 stubs above
- [ ] `bin/generate-compiled`: detect language dirs, emit `compiled.main.en.md`
  and `compiled.main.tl.md`
- [ ] Update README file-structure section

## Phase 3 — CI workflow

File: `psychic-petals-novel/.github/workflows/sync-to-db.yml`

- [ ] Trigger paths already cover `main/**/*.md` — no change needed there
- [ ] Split changed/deleted lists by language prefix; invoke sync per group
- [ ] Requires Phase 1 pushed to the platform repo's default branch BEFORE the
  restructure push fires CI

## Phase 4 — Frontend (discovery-first)

Repo: `psychic-petals-platform/frontend/`

- [ ] Read how the reader view loads `psychic_petals`
- [ ] Add language toggle swapping the novel doc (`GET /api/novel` already lists both);
  1:1 chapter numbering preserves reading position
- [ ] Sized separately — may be its own follow-up session

## Push order (each submodule pushes independently)

1. Backend (Phase 1) → verify tests → push platform repo
2. Novel restructure (Phases 2–3) → push novel repo → watch Actions run
3. Frontend (Phase 4) → push platform repo

## Risks / notes

- **Reconciliation footgun**: if files move before the dual-form regex lands,
  the next sync sees zero valid chapters and deletes all English chapters from
  Firestore. Phase 1 must be deployed first.
- Stubs sync as `published: false` episodes (auto-created default) — invisible
  to readers, safe to push.
- `reset-novel.js` is destructive by design: it wipes API-managed fields too
  (e.g., chapter `notes` set through the dashboard). Only use when disk content
  is known-good.
- Do not commit `.env` files or raw service-account JSON.
