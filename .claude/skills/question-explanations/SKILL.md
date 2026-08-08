---
name: question-explanations
description: Use when asked to generate, update or publish pre-generated "Ask AI" explanations (объяснения) for Saobraćaj exam questions — the offline half of the ask_ai feature. Writes app/explanation_content/<categoryId>.json (one explanation per question) from the bundled question assets, konspekts and parsed_zakon.json, and uploads them to the backend database; authoring works offline, publishing needs VPS credentials. Never touches app source code.
---

# Question explanations (Ask AI pre-generation)

Generates a Russian-language explanation for **every question** of a category,
saves them as `app/explanation_content/<categoryId>.json` and publishes them to
the backend (`saobracaj_question_explanations`, served by the feature-gated
`questionExplanation(s)` GraphQL queries). An explanation answers the user's
most common question — «почему правильный ответ такой» — instantly and at zero
marginal cost, so the live Ask-AI chat is only needed for genuine interactivity.

Document format and writing style: `reference/format.md` — **read it first**;
the JSON shape is the contract with the Flutter client, don't improvise.

Run everything through `scripts/explanations_cli.py` (stdlib-only Python 3) —
never open `assets/allQuestions.json` (1.4 MB) or `assets/parsed_zakon.json`
(4085 fragments) directly with the Read tool.

## Workflow for one category

1. **Scope.** `python3 scripts/explanations_cli.py categories` — pick the
   category, note its size and subcategories.

2. **Dump the authoring context.**
   ```
   python3 scripts/explanations_cli.py context 25 [--subcategory N] [--qid N]
   ```
   Per question: qId, subcategory, image flag, `choose=N` for multi-answer,
   Serbian text, RU translation, all choices (indexed, ✓ = correct, with RU
   translations) and — critically — the konspekt blocks already mapped to
   this qId (`KONSPEKT[section-id]: …`). The konspekt block usually *is* the
   rule the explanation should teach; the section id goes into `sources`.

3. **Find the law article.** Questions rarely carry a ready `ZAKON:` link;
   search for the deciding article yourself:
   ```
   python3 scripts/explanations_cli.py zakon-search "одстојање"
   python3 scripts/explanations_cli.py zakon 187
   ```
   Search Serbian terms from the question first (the law text is sr+ru
   aligned); then dump the article and pick the paragraph that actually
   decides the answer. Definition questions almost always resolve to чл. 7
   (значења израза). Don't cite an article you haven't dumped — the validator
   only checks the link *exists*, not that it's relevant.

4. **Questions with images** (`IMG(assets/img/<qId>.jpeg)`): the text and
   choices usually make the picture inferable; when the answer genuinely
   depends on what is shown (vehicle-recognition questions), Read the image
   file — they are small.

5. **Write the explanations** following `reference/format.md`. For batch
   generation, fan out over question ranges: each writer produces a JSON
   *fragment* (an array of documents) and the fragments are collected with
   ```
   python3 scripts/explanations_cli.py merge 25 /tmp/frag_a.json /tmp/frag_b.json
   ```
   (idempotent: re-merging a corrected fragment replaces by questionId).

6. **Validate.**
   ```
   python3 scripts/explanations_cli.py validate 25
   ```
   Checks structure, lengths, that `wrongChoices` point at real (and
   incorrect) options with verbatim text, that every `sources`/inline link
   resolves (zakon article+paragraph, konspekt section, question id), and
   **coverage**: every question of the category must have an explanation
   (`--allow-partial` downgrades that to a warning during incremental work).
   Fix and re-run until `OK`.

7. **Spot-check.** Re-read 5 random explanations against their `context`
   dump: does the stated rule actually decide the answer? Is the cited
   article the deciding one (dump it again if unsure)? Is the trap named?
   Fix, bump nothing (still unpublished), re-validate.

8. **Publish.** Credentials come from the environment (same variables as the
   konspekt CLI — `KONSPEKT_VPS_HOST` etc.); ask the operator, never commit
   them:
   ```
   KONSPEKT_VPS_HOST=<ip> KONSPEKT_VPS_PASSWORD=<pw> \
     python3 scripts/explanations_cli.py publish 25
   ```
   `publish` re-runs `validate` first and upserts per (question, lang), so
   re-publishing simply replaces the documents. **Bump each changed
   document's `version`** when re-publishing an edit — the client caches by
   it. `--dry-run` validates and sizes the payload without a database;
   `--postgres URL` targets a local database for testing; `published` shows
   what the database serves.

## Notes

- `merge` snaps a `wrongChoices[].text` to the asset's verbatim string when the
  two differ only in whitespace — the assets write numbers with a non-breaking
  space (`200 m`, `50 cm3`), which is impossible to reproduce by hand. A real
  mismatch (wrong option, re-ordered choices) still fails validation.
- Content only: this skill writes `explanation_content/` and the database —
  never app source code. The app-side tab is a separate work item.
- Every question must land somewhere between three grounding sources: a
  konspekt block, a law article, or (for picture questions) the image itself.
  If none fits — the explanation still must not invent a rule; write from
  the official choices and flag the question in your session summary as a
  content-gap candidate (thin konspekt / no article), the operator collects
  those.
- Costs are logged per category when doing the mass run: note token spend and
  questions/hour in the task, the epic tracks economics.
- The Serbian pass is a separate file and a separate publish (see
  `reference/format.md`), gated on the serbian-content epic.
