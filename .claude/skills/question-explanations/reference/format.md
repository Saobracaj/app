# Explanation document format

One JSON file per (question, language):

- `explanation_content/<categoryId>/<qId>.json` — Russian (the primary
  pipeline language);
- `explanation_content/<categoryId>/<qId>.sr.json` — Serbian (authored later,
  same schema with `"lang": "sr"` and Serbian text).

The file is stored in the backend **verbatim** (table
`saobracaj_question_explanations`, one row per (question, lang)) and parsed by
the Flutter client, so the schema below is a contract — `validate` enforces
it, and anything outside it is rejected.

## Schema

```json
{
  "questionId": 7932,
  "lang": "ru",
  "version": 1,
  "summary": "Водитель — это тот, кто управляет транспортным средством на дороге; ни наличие прав, ни толкание машины руками водителем не делают.",
  "whyCorrect": "По [определению из закона](zakon?chlan=7&paragraph=79) _возач_ (водитель) — лицо, которое **управляет** транспортным средством на дороге. Ключевое слово — управляет: важно фактическое действие, а не документы.",
  "whyOthersWrong": "· _лице које … гура или вуче возило_ — человек, толкающий или тянущий машину, по закону пешеход, а не водитель.\n· _свако лице које има возачку дозволу_ — права в кармане не делают человека водителем, пока он не управляет транспортным средством.",
  "memoryHook": "Водитель = управляет здесь и сейчас; документы и мускульная сила не в счёт.",
  "sources": [
    {"type": "zakon", "title": "Члан 7, тачка 79 — определение водителя", "link": "zakon?chlan=7&paragraph=79"},
    {"type": "konspekt", "title": "Конспект: Водитель и пешеход", "link": "konspekt?category=25&section=vozac-i-pesak"}
  ]
}
```

## Fields

| Field | Type | Rules |
|---|---|---|
| `questionId` | int | must equal the file name and exist in `allQuestions.json` |
| `lang` | `"ru"` \| `"sr"` | must match the file suffix |
| `version` | int ≥ 1 | bump on every published change — the client caches by it |
| `summary` | string | 20–350 chars, **one plain sentence or two**: the direct answer to «почему правильный ответ такой». No line breaks, no markdown links (italics/bold allowed). Rendered as the lead paragraph. |
| `whyCorrect` | markdown | 30–2600 chars. Why the correct choice(s) are correct — the rule/definition behind them, with an inline law or konspekt link where it genuinely helps. |
| `whyOthersWrong` | markdown \| null | 20–2600 chars. Why each distractor is wrong, one `·`-bullet line per choice, quoting the choice in Serbian italics. `null` only when the question has no meaningful distractors (e.g. a bare numeric fact). |
| `memoryHook` | string \| null | 10–300 chars, single line. A mnemonic or logic chain («спрашивают X → выбирай Y»). Rendered as a highlighted callout. `null` when nothing non-trivial to offer. |
| `sources` | array, 1–4 | each `{type, title, link}`; `type` is `zakon` or `konspekt`, `link` starts with the same prefix. Rendered as tappable chips. At least one source; prefer one `zakon` + one `konspekt` when both exist. |

No other keys are allowed. `whyOthersWrong` and `memoryHook` are required
keys — use `null` explicitly, don't omit them.

## Links

Exactly the same syntax the app already renders in comments and konspekts:

- law: `[текст ссылки](zakon?chlan=7&paragraph=79)` — `chlan` required,
  `chapter`/`paragraph` optional; must exist in `assets/parsed_zakon.json`
  (both are strings there — `paragraph=79` is the *global point number* the
  parsed law uses, not the article-local one);
- konspekt section: `[текст](konspekt?category=25&section=vozac-i-pesak)` —
  the section must exist in `konspekt_content/<category>.json`;
- another question: `[№7921](question?id=7921)` — sparingly, only when the
  contrast with that question genuinely teaches something.

`validate` resolves every link and fails on dead ones.
