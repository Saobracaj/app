# Konspekt JSON format

One file per category: `app/konspekt_content/<categoryId>.json` — the authored
source, published from there into the backend database (`saobracaj_konspekts`)
with `konspekt_cli.py publish`. The app downloads the document over GraphQL; it
is no longer a bundled Flutter asset, so the JSON shape below is what the
backend stores verbatim and what `lib/konspekt/models/konspekt.dart` parses.
Text is
markdown; every localized string is a `{"ru": ..., "sr": ...}` object — only
`ru` is filled today, `sr` is `null` (reserved, same idea as
`parsed_zakon.json`'s `sr`/`ru` pair).

```json
{
  "version": 1,
  "categoryId": "25",
  "categoryName": {
    "sr": "Oснове безбедности саобраћаја",
    "ru": "Основы безопасности дорожного движения"
  },
  "intro": { "ru": "markdown: как отвечать на вопросы этой категории", "sr": null },
  "sections": [
    {
      "id": "ko-regulise-saobracaj",
      "title": { "ru": "Кто регулирует движение", "sr": null },
      "content": { "ru": "markdown…", "sr": null },
      "blocks": [
        {
          "content": { "ru": "первый фрагмент markdown…", "sr": null },
          "questionIds": [7921]
        },
        {
          "content": { "ru": "второй фрагмент…", "sr": null },
          "questionIds": [7923]
        }
      ],
      "illustrations": [
        {
          "id": "preticanje-vs-obilazenje",
          "type": "animation",
          "description": {
            "ru": "Что должно быть на иллюстрации, для художника/генератора",
            "sr": null
          }
        }
      ],
      "questionIds": [7921, 7923]
    }
  ],
  "dictionary": {
    "title": { "ru": "Словарь ключевых слов", "sr": null },
    "content": { "ru": "markdown-таблица: слово | перевод", "sr": null }
  }
}
```

## Field semantics

- `sections[].id` — kebab-case slug, stable anchor. The app links to a
  section as `konspekt?category=25&section=<id>` (same URI style as the
  existing `zakon?chapter=…&chlan=…&paragraph=…` links in comments).
- `sections[].questionIds` — **full mapping**: every question this section
  helps answer. The union over all sections must cover every question of the
  category (the validator enforces this). One question may appear in several
  sections.
- `sections[].blocks` — the section's markdown split into self-contained
  fragments, each mapped to the questions **that exact fragment** answers.
  This is what the app shows on a question's «Конспект» tab (only the blocks
  listing that qId), so keep blocks small — one rule / one confusable pair /
  one fact, обычно 300–700 символов. Invariants (validator-enforced):
  - blocks are **authored first**; `content.ru` is generated from them —
    run `konspekt_cli.py sync-blocks <file>` after editing blocks, the
    validator requires `content.ru == "\n\n".join(blocks…content.ru)`;
  - the union of the blocks' `questionIds` must equal the section's
    `questionIds`; a block with an empty `questionIds` is allowed —
    context-only text (вводная секции) shown on the full page but never
    excerpted for a question;
  - a block must read as a standalone excerpt: don't start one with «а ещё»,
    a bare table continuation, or a pronoun referring to the previous block.
  Sections without `blocks` are legal (pre-v2 documents): the app then falls
  back to showing the whole section for its questions.
- Inline example-question links in markdown: `[№7921](question?id=7921)` —
  a handful of representative examples per section, not the whole list
  (the whole list lives in `questionIds`).
- Cross-section links in markdown: `[текст](konspekt?category=25&section=slug)`.
- Illustration placeholder in markdown: `![альт-текст](illustration:<id>)`,
  where `<id>` matches an entry in that section's `illustrations` array.
  The assets will be produced later from `description.ru`; `type` is
  `image` or `animation`.
- `intro` — optional; the "how to think" opening (общая логика ответов).
- `dictionary` — required; markdown table of key Serbian terms and Russian
  translations (see style guide for which words belong there).
