---
name: question-explanations
description: Use when asked to generate, update, validate or publish pre-generated "Ask AI" explanations (развёрнутые объяснения) for Saobraćaj exam questions — per-question JSON documents explaining why the correct answer is correct, with law and konspekt links. Writes app/explanation_content/<categoryId>/<qId>.json and uploads to the backend database; authoring works offline, publishing needs VPS credentials. Never touches app source code.
---

# Question explanations (Ask AI pre-generation)

Generates the **pre-generated explanation** every question gets on the app's
«Ask AI» tab: a structured document answering the most common question —
«почему правильный ответ именно этот» — instantly and at zero marginal cost,
so the live LLM chat is reserved for what genuinely needs interactivity.

One JSON file per question under `explanation_content/<categoryId>/`, format
fixed in `reference/format.md` (a contract with the Flutter client — follow it
exactly). Published to the backend table `saobracaj_question_explanations`,
served over GraphQL `questionExplanation(questionId, lang)` /
`questionExplanations(questionIds, lang)` behind the premium `ask_ai` flag.

Run everything through `scripts/explanations_cli.py` (stdlib-only Python 3) —
never open `assets/allQuestions.json` (1.4 MB) or `assets/parsed_zakon.json`
(~4000 entries) directly with the Read tool.

## Workflow for one category

1. **See what's missing.**
   ```
   python3 scripts/explanations_cli.py queue 25
   ```
   Lists question ids of the category with no local explanation yet.

2. **Pull the context, a batch at a time** (8–12 questions per batch keeps
   the context readable):
   ```
   python3 scripts/explanations_cli.py context 7921 7922 7923
   ```
   Per question: Serbian text, RU translation hint, choices with the correct
   ones marked `✓`, `choose=N` for multi-selects, image flag — plus **every
   konspekt block mapped to this question** (per-block `questionIds` from
   `konspekt_content/<cat>.json`) with its ready-made section link.

3. **Find the law when the konspekt is not enough.**
   ```
   python3 scripts/explanations_cli.py search-law трамвај
   python3 scripts/explanations_cli.py search-law --chlan 29
   ```
   Prints matching paragraphs with their ready-made `zakon?…` links. The
   konspekt block usually names the relevant article — verify the exact
   paragraph before citing it, never cite from memory.

4. **Write the JSON files** following `reference/format.md`. Style:
   - **Explain the rule, don't restate the answer.** «Правильно, потому что
     так в законе» — брак; вытащи определение или логику, из которых ответ
     следует.
   - Serbian exam terms in _italics_, untranslated, with a Russian translation
     in brackets on first mention — exactly like the konspekts.
   - **Never refer to choices by position** («вариант Б», «третий вариант») —
     the app may shuffle them. Quote the choice's Serbian text in italics.
   - `whyOthersWrong`: one `·`-bullet per distractor. For multi-selects,
     re-check every choice against the rule, the way the exam does.
   - `memoryHook` is the «спрашивают X → выбирай Y» chain when one exists;
     don't force it — `null` beats a vacuous hook.
   - Every law citation must come from an actual `search-law` hit; `validate`
     catches dead links but not wrong-but-existing ones, so check the
     paragraph text really supports the claim.
   - For `IMG` questions the text + choices are usually enough; if the answer
     genuinely depends on the picture, Read `assets/img/<qId>.jpeg`.

5. **Validate the whole category** (also reports which questions are still
   uncovered):
   ```
   python3 scripts/explanations_cli.py validate 25
   ```
   Fix errors and re-run until `OK`.

6. **Spot-check yourself.** Re-read a few generated files against their
   `context` dumps: does `whyCorrect` actually derive the answer, does every
   distractor bullet name a real choice, does the cited paragraph say what
   the text claims it says?

7. **Publish to the backend.** Credentials come from the environment — ask
   the operator, never commit them:
   ```
   KONSPEKT_VPS_HOST=<ip> KONSPEKT_VPS_PASSWORD=<ssh password> \
     python3 scripts/explanations_cli.py publish 25
   ```
   `publish` re-runs `validate` first and upserts row by row, so
   re-publishing just replaces the content. Bump a file's `version` when you
   change a published explanation — the client caches by it. `--dry-run`
   validates and reports the payload size without touching the database;
   `published --category 25` shows coverage the database currently serves.

## Serbian version

Same schema with `"lang": "sr"` in `<qId>.sr.json`, published with
`--lang sr`. Adapt, don't translate: drop the RU translation brackets and any
«как по-русски» scaffolding — the Serbian terms are the reader's native
words. Serbian Cyrillic only. (Mirrors the konspekt skill's sr rules.)

## Notes

- Content only: this skill writes `explanation_content/` and the database.
  Do not touch app source code or `pubspec.yaml`.
- The explanation complements — and must not contradict — the question's
  editorial comment and the konspekt. When the konspekt block and the law
  disagree, the law wins; flag the konspekt for a fix in your session notes.
- Questions whose category has no konspekt still get explanations — the law
  link is then the only source; note such questions when reporting (they are
  candidates for konspekt work).
- A regenerated explanation replaces the old one wholesale (same file, bump
  `version`) — there is no draft/review state in the table; git history of
  `explanation_content/` is the review trail.
