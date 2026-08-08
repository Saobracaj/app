---
name: category-konspekt
description: Use when asked to create or update a "конспект" (RU study notes / cheat-sheet) for a category of Saobraćaj exam questions, to check konspekt coverage, or to publish a konspekt to the backend. Writes app/konspekt_content/<categoryId>.json from the bundled question assets and uploads it to the backend database; authoring works offline, publishing needs VPS credentials. Never touches app source code.
---

# Category konspekt

Generates a Russian-language konspekt (study cheat-sheet) for one question
category, saves it as `app/konspekt_content/<categoryId>.json` and publishes it
to the **backend database**, which is where the app reads konspekts from (they
used to be bundled assets; see step 8). The
konspekt's goal is that a user who read it can answer **every** question of
the category by following simple logic chains — it is exam-oriented, not a
law summary. Format: `reference/format.md`. Writing style (the important
part): `reference/style-guide.md`.

Run everything through `scripts/konspekt_cli.py` (stdlib-only Python 3) —
never open `assets/allQuestions.json` (1.4 MB) directly with the Read tool.

## Workflow for one category

1. **Scope the category.**
   ```
   python3 scripts/konspekt_cli.py categories
   ```
   Shows every category with its subcategories and question counts. A
   typical category is 30–150 questions.

2. **Read all questions of the category.**
   ```
   python3 scripts/konspekt_cli.py questions 25
   ```
   Compact dump: per question — qId, subcategory, image flag, Serbian text,
   RU translation hint, choices with the correct ones marked `✓`. For a
   large category (>120 questions) dump one `--subcategory` at a time.
   You must actually read the whole dump: the konspekt is built from the
   *answers*, and grouping/traps only emerge when you see all of them.

3. **Cluster and design sections.** Group questions by the *rule that
   answers them*, not by subcategory. While reading, note: repeated correct
   answers ("this option is always correct"), confusable term pairs, numeric
   facts that are actually asked about. Aim for 5–15 sections; every
   question must land in at least one section's `questionIds`.

4. **Handle images.** Questions flagged `IMG` reference
   `assets/img/<qId>.jpeg`. Usually the text + choices are enough to infer
   what the picture shows. If a correct answer genuinely can't be
   understood without the picture (e.g. "which vehicle is shown"), Read a
   few of those images directly — they are small; don't read all of them.

5. **Write the konspekt JSON** to `app/konspekt_content/<categoryId>.json`
   following `reference/format.md` exactly (localized strings are
   `{"ru": …, "sr": null}` — `sr` reserved for later). Content rules are in
   `reference/style-guide.md`; the non-negotiables:
   - author each section as `blocks` — small standalone fragments (one
     rule/fact each) with **per-block** `questionIds` — then generate
     `content` with `konspekt_cli.py sync-blocks <file>`; the app excerpts
     individual blocks for a question's «Конспект» tab, so a block is the
     unit users actually see there (see `reference/format.md`);
   - logic chains ("спрашивают X → выбирай Z") over theory;
   - Serbian terms in *italics*, untranslated in running text, translation
     in brackets on first mention;
   - inline example links `[№7921](question?id=7921)` (2–4 per section) on
     top of the full `questionIds` mapping;
   - illustration placeholders `![alt](illustration:<slug>)` plus an
     `illustrations[]` entry whose `description.ru` is a brief for the
     artist — assets are produced later, never invent real image paths;
   - a `dictionary` block: markdown table of the key Serbian exam terms
     with translations.

6. **Validate.**
   ```
   python3 scripts/konspekt_cli.py validate ../../../konspekt_content/25.json
   ```
   Checks structure, slugs, that every questionId/inline link belongs to
   the category, that illustration markers match `illustrations[]`, that
   section cross-links resolve, and — most importantly — **coverage**:
   every question of the category must appear in some section's
   `questionIds`. Fix errors and re-run until `OK`.

7. **Spot-check yourself.** Pick 5 random questions from the dump and check
   the konspekt actually gives the rule that answers each of them (not just
   lists the qId). If a question is only answerable by rote, its section
   must state the exact fact to memorize.

8. **Publish to the backend.** The app downloads konspekts from
   `saobracaj_backend` (table `saobracaj_konspekts`, GraphQL
   `konspektCategories` / `konspekt`), so a konspekt that is not published is
   invisible to users. Credentials come from the environment — ask the
   operator for them, never commit them:
   ```
   KONSPEKT_VPS_HOST=<ip> KONSPEKT_VPS_PASSWORD=<ssh password> \
     python3 scripts/konspekt_cli.py publish 25
   ```
   `publish` re-runs `validate` first, refuses a file whose `categoryId`
   disagrees with the argument, creates the table if it is missing and
   upserts the row (so re-publishing just replaces the content). Bump the
   document's `version` when you change a published konspekt — the client
   uses it to notice that its cached copy is stale.

   Related commands: `published` (what the database currently serves) and
   `pull 25` (write the stored document back to
   `konspekt_content/25.json`, e.g. before editing content someone else
   published). `--dry-run` validates and reports the payload size without
   touching the database.

## Serbian version (`sr` fields)

The app shows konspekts in Serbian for everyone **except** users with the
`russian_content` feature resolved on (backend grant + the popup/settings
opt-in) — the `sr` fields are the primary content, not an extra. Authoring
rules:

- **Serbian Cyrillic only** (ћирилица) — never Latin, never a mix.
- **Adapt, don't translate.** The RU text leans on the reader knowing
  Russian: Serbian terms in italics with a Russian translation in brackets,
  "как по-русски X" comparisons, the RU-translation dictionary. In the `sr`
  version the exam terms are the reader's native words — drop translation
  brackets and any "in Russian this is called…" scaffolding, and rewrite
  those sentences around the term itself. Everything else (logic chains,
  facts, traps, inline `[№7921](question?id=7921)` links, illustration
  markers) carries over 1:1.
- Author `sr` **per block** in the same file (`blocks[].content.sr`), then
  run `sync-blocks` — it regenerates `content.sr` alongside `content.ru`
  once at least one block of a section carries Serbian. Translate whole
  sections at a time: partially-Serbian sections render with gaps
  (`validate` warns about them).
- `title.sr`, `categoryName.sr` and `intro.sr` are needed too; the
  `dictionary` is inherently RU-oriented (translations *into* Russian) and
  stays RU-only — the app only offers it to `russian_content` users.
- Bump `version` and re-`publish` — the sr fields ship inside the same
  document.

## Notes

- Content only: this skill writes `konspekt_content/` and the database. Do
  not touch app source code or `pubspec.yaml`.
- `konspekt_content/*.json` is the editable source kept in git; the database
  copy is what users actually get. Keep them in sync by always publishing
  after an edit (`test/konspekt_model_test.dart` validates the local files).
- Updating an existing konspekt: dump questions again, diff against
  `questionIds` coverage (`validate` reports missing ids), extend or edit
  only affected sections, bump `version`, re-`publish`.
- Migrating a pre-blocks konspekt: cut each section's existing `content.ru`
  into `blocks` strictly at paragraph (`\n\n`) boundaries — don't rewrite the
  text — assign per-block `questionIds` from the question dump, run
  `sync-blocks` (must report 0 changed sections if the cut was clean), then
  `validate`, bump `version`, re-`publish`. The app falls back to whole
  sections until then, so migration can go category by category.
