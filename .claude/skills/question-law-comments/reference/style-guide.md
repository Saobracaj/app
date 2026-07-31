# Comment style guide

Distilled from the ~35 human-approved (`READY`) comments as of 2026-07-23.
Pull fresh examples any time with:
```
python3 scripts/comments_cli.py queue --status ready --limit 50
python3 scripts/comments_cli.py show <ids...>
```

## Language and formatting

- Body text is **Russian**. Serbian legal/technical terms stay in Serbian,
  wrapped in `_italics_` (single underscores) or `*italics*` (single
  asterisks) — both are used interchangeably in the corpus, pick one and be
  consistent within a comment.
- `**bold**` marks the key fact the reader must remember (a number, a
  decisive condition, the one word that disqualifies the wrong answers).
- Bulleted lists (`* item` or `- item`) are used to enumerate: legal
  conditions from a definition, or the answer choices with a verdict
  attached (`✓ item — почему подходит` / `item — не подходит, так как ...`).
- Headings (`# Лайфхак`) appear occasionally for a short memorable
  takeaway at the end of a comment — optional, use only when there's a
  genuinely reusable rule of thumb (e.g. "X always the right answer for
  this class of question").
- Comments range from one sentence ("В вопросе указано определение X из
  закона.") to several paragraphs with a bulleted breakdown of every
  choice. Match the length to how much a plain law citation actually
  explains — don't pad.

## Law links

Format: `[link text](zakon?chapter=X&chlan=Y&paragraph=Z)` or with the full
host prefix `https://saobracaj.app/zakon?chapter=X&chlan=Y&paragraph=Z` —
both resolve the same route in the app; either is fine, prefer the relative
form (shorter, matches the majority of the corpus).

- `chapter` is a roman numeral (`I`..`XXII`, or `SPECIAL`), `chlan` is the
  article number, `paragraph` is the index of a specific sub-item inside
  that article. Get exact values from `search-law` — never hand-type them.
- `paragraph=0` conventionally means "the article as a whole" (points at
  the "Члан N." heading line) rather than one specific sub-item — used when
  citing an entire article rather than one definition/clause.
- Link text is almost always one of:
  - `определение _<термин>_ из закона` / `определению _<термин>_ из закона`
    — when citing a term definition (these are virtually all in chlan 7).
  - `статьи N закона` / `статье N закона` — when citing a procedural
    article rather than a definition.
- One comment can and often does cite multiple paragraphs (e.g. one link
  per bullet point when several definitions are being distinguished).

## Common shapes

1. **One-liner citation** — the question already states/matches a legal
   definition almost verbatim; just point at it.
   > В вопросе указано [определение _претицања_ (обгона) из закона](zakon?chlan=7&paragraph=85).

2. **Definition breakdown** — quote/restate every condition from the law
   definition as a bullet list, then map each answer choice against the
   conditions.

3. **Elimination** — identify the one property that rules out the wrong
   choices, state it in bold, then link the definition that confirms it.

4. **Enumerated exhaustive list** — for "who/what is allowed to X"
   questions: list the exhaustive set from the law, then note "больше
   никто/ничто" (nothing else qualifies) with a citation.

Always ground the explanation in the *law text*, not general driving
knowledge — the whole point of these comments is to show which law
paragraph makes an answer correct, so students can look it up themselves.
