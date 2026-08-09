# Question explanation format

One file per category and language:
`app/explanation_content/<categoryId>.json` (Russian) and
`<categoryId>.sr.json` (Serbian, later) — the authored source, published from
there into the backend (`saobracaj_question_explanations`, one row per
question+lang) with `explanations_cli.py publish`. The backend stores each
document **verbatim** and the app parses it with its own model, so the shape
below is the contract between the generation pipeline and the Flutter client.

```json
{
 "categoryId": "25",
 "lang": "ru",
 "explanations": [
  {
   "questionId": 7921,
   "lang": "ru",
   "version": 1,
   "summary": "Непосредственно регулируют движение только полицейские в форме — остальные службы лишь контролируют отдельные виды транспорта.",
   "explanation": "markdown: почему правильный ответ правильный…",
   "wrongChoices": [
    {
     "index": 0,
     "text": "инспектори за друмски саобраћај",
     "why": "markdown: почему этот вариант неверен…"
    }
   ],
   "sources": [
    {
     "type": "zakon",
     "title": "Чл. 2 — кто регулирует движение",
     "uri": "zakon?chapter=I&chlan=2&paragraph=1"
    },
    {
     "type": "konspekt",
     "title": "Конспект: кто регулирует движение",
     "uri": "konspekt?category=25&section=ko-regulise-saobracaj"
    }
   ]
  }
 ]
}
```

## Field semantics

- `questionId` — the official `qId` from the assets; `lang` must repeat the
  file's language (the backend rejects a mismatch); `version` starts at 1 —
  bump it when re-publishing a changed document, the client uses it to notice
  a stale cache.
- `summary` — **plain text**, one or two sentences, ≤ 300 chars. The direct
  answer to «почему правильный ответ такой»: the rule itself, not a preamble.
  Shown first and standalone (list previews, collapsed state), so it must not
  depend on the rest of the document and must not contain markdown.
- `explanation` — markdown, ~150–2500 chars (2–5 short paragraphs or a
  paragraph + list). The reasoning: the rule, the logic chain from rule to
  answer, and the trap the question sets, with the law article linked inline.
  It complements `summary` (which the user has already read) — don't repeat
  it verbatim as the opening line.
- `wrongChoices[]` — why each incorrect option is wrong. `index` is the
  0-based position in the question's `Choices`; `text` is the option's
  Serbian text **verbatim** (the validator checks both against the assets, so
  a re-ordering of options is caught rather than silently mis-attributed).
  `why` is markdown, ≤ 500 chars — ideally not just "это неверно", but what
  makes the option tempting and in which situation it *would* be true.
  Required for questions with more than two options; for binary (да/нет)
  questions the array may be empty when the explanation already covers it.
- `sources[]` — 1–3 entries, what the explanation is grounded in, rendered by
  the app as tappable links. `type`: `zakon` | `konspekt` | `question`.
  Order: the law article first, then the konspekt section. Every question
  should normally cite the law (the validator warns otherwise).
- Link URIs — the same app URI scheme the konspekts and comments use:
  - law: `zakon?chapter=<roman>&chlan=<N>&paragraph=<M>` (`paragraph=0`
    links the whole article);
  - konspekt section: `konspekt?category=<id>&section=<slug>`;
  - another question: `question?id=<qId>`.
  The same URIs may appear as inline markdown links inside `explanation` and
  `why`; the validator resolves every link against the assets.

## Style (RU)

The reader has just answered the question (rightly or wrongly) and is looking
at it. Don't retell the question or enumerate the options — explain the rule
that decides it.

- Start from the rule, not from the question: «Непосредственно регулировать
  движение может только полиция…», not «В этом вопросе спрашивается…».
- Logic chain over recitation: «спрашивают, кто *регулирует* → регулирует
  полиция; остальные *контролируют* свой транспорт» — the konspekt style.
- Serbian exam terms in *italics*, untranslated, with a Russian translation
  in brackets on first mention: «*одстојање* (дистанция по ходу движения)».
- Name the trap explicitly when the question has one: confusable term pair,
  a near-miss number, an option that is true in a different situation.
- Cite the law by article: «по чл. 2 ЗОБС» with an inline `zakon?…` link.
  Prefer the paragraph that actually decides the answer over ¶0.
- No filler («как известно», «следует отметить»), no moralizing, no
  «правильный ответ — Б» (the app already shows which option is correct).

## Serbian version (`sr`, later)

A separate `<categoryId>.sr.json` file with `lang: "sr"` throughout —
explanations are stored per language, unlike konspekts. Serbian Cyrillic
only; adapt rather than translate (drop the translation brackets and
«по-русски это…» scaffolding — the exam terms are the reader's native
words). Same structure, same links, same validator.
