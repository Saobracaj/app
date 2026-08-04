---
name: category-konspekt
description: Use when asked to create or update a "конспект" (RU study notes / cheat-sheet) for a category of Saobraćaj exam questions, or to check konspekt coverage. Produces app/assets/konspekt/<categoryId>.json from the bundled question assets; works fully offline, never touches app source code.
---

# Category konspekt

Generates a Russian-language konspekt (study cheat-sheet) for one question
category and saves it as `app/assets/konspekt/<categoryId>.json`. The
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

5. **Write the konspekt JSON** to `app/assets/konspekt/<categoryId>.json`
   following `reference/format.md` exactly (localized strings are
   `{"ru": …, "sr": null}` — `sr` reserved for later). Content rules are in
   `reference/style-guide.md`; the non-negotiables:
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
   python3 scripts/konspekt_cli.py validate ../../../assets/konspekt/25.json
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

## Notes

- The file is not yet wired into the Flutter app (no pubspec entry, no
  screen). Generating content is this skill's whole job; do not touch app
  code or `pubspec.yaml` unless explicitly asked.
- Updating an existing konspekt: dump questions again, diff against
  `questionIds` coverage (`validate` reports missing ids), extend or edit
  only affected sections.
