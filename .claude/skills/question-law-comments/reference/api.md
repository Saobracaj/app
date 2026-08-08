# API cheatsheet

You normally don't need any of this — `scripts/comments_cli.py` wraps it
all. Read this only if you need to debug the CLI or extend it.

API: `saobracaj_backend` (Rust/async-graphql, on top of `base_rust_backend`),
endpoint `https://api.saobracaj.gleb.at/graphql`. Resolvers live in
`saobracaj_backend/src/comments/graphql.rs`, storage in
`.../comments/repository.rs`, types in `.../comments/model.rs`. (The old
Kotlin server on Cloud Run is legacy — its `comments`/`draft` fields are gone
from this skill.)

## Auth

- `login(email, password)` (mutation) -> `{ accessToken, refreshToken }`.
  There is **no self sign-up path that helps here**: reading needs any
  authenticated user, and `allQuestionComments` plus every mutation are
  guarded by the `edit_comments` permission, which only the operator can
  grant. Credentials come from `SAOBRACAJ_COMMENTS_EMAIL` /
  `SAOBRACAJ_COMMENTS_PASSWORD`.
- `refreshToken(refreshToken)` (mutation) -> a new `{ accessToken,
  refreshToken }` pair. Access tokens are short-lived; the CLI caches the
  refresh token and re-logs in when it expires.
- Send `Authorization: Bearer <accessToken>` on every subsequent call.
- Errors come back as HTTP 200 with a top-level `errors` array (e.g.
  `authorization required`, `extensions.code = authorization_required`), not
  as an HTTP error status — always check for `errors` in the response body.

## Comment id == question id

A comment's `id` (`Int`, i.e. GraphQL `Int!` — the legacy API used `Long`) is
the same value as the question's `qId`/`qcId` in
`app/assets/allQuestions.json`. Rows are created lazily: `questionComment`
returns `null` while none exists (treat that as `PENDING`), and
`saveCommentDraft` creates the row on first write.

## Text blocks are per-language

`text`, `draft` and each entry of `history` are `CommentText { items
[{ lang, text }], created, updated }` — one item per language, `lang` being
the `Language` enum (`RU` | `SR`). The legacy API's `text { text { lang
text } }` shape no longer exists; the field is `items`.

`saveCommentDraft(id, draft, language)` replaces **only** the fragment of
that language and preserves the other one, so writing SR never clobbers RU.
`language` defaults to `RU` server-side.

## Queries/mutations used by this skill

```graphql
query { allQuestionComments { id status draft { items { lang } } text { items { lang } } } }   # `queue`
query($id: Int!) { questionComment(id: $id) { status draft { items { lang text } } text { items { lang text } } } }
mutation($id: Int!, $draft: String!, $lang: Language!) {
  saveCommentDraft(id: $id, draft: $draft, language: $lang) { id status }
}
```

`saveCommentDraft` flips `status` from `PENDING` to `DRAFT` the first time;
later calls just overwrite that language's draft fragment in place.

## `CommentStatus` state machine

Ground truth: `CommentsRepository::save_draft`/`apply_draft` in
`saobracaj_backend/src/comments/repository.rs`, enum in
`saobracaj_backend/src/comments/model.rs`. The Angular panel's
Russian labels for each status are in
`saobracaj_panel_angular/src/app/components/markdown-editor/markdown-editor.component.ts`
(`getStatusText()`).

```
PENDING -- saveCommentDraft() --> DRAFT -- applyCommentDraft() --> DRAFT or MODERATION -- (human, in the Angular panel) --> READY
"Ожидает"          "Черновик"                  see note below     "На модерации"          "Готово"
```

- `PENDING` ("Ожидает"): no draft saved yet — the empty initial state.
  **This is a different, unrelated status from "pending" used loosely in
  English to mean "awaiting review."** Don't conflate the two.
- `DRAFT` ("Черновик"): someone saved draft text, not yet applied. **This
  is where `submit` leaves everything — it never calls `applyCommentDraft`.** A
  human reviews drafts in the Angular admin panel (`markdown-editor` /
  `question-preview` components) and applies them from there. This is the
  correct "awaiting human review" state for content this skill writes.
- `MODERATION` ("На модерации"): set by `apply_draft` **only when a `text`
  was already published before** (i.e. this is a re-edit of a
  previously-live comment, now needing re-review); a `READY` comment stays
  `READY`. On the *first* apply (no prior `text`) the draft is copied into
  `text` (so it goes live) but the status stays `DRAFT` — a quirk carried
  over from the legacy server, not something this skill controls.
- `READY` ("Готово"): approved/done. The Rust API does expose
  `setCommentStatus(id, status)` (also `edit_comments`-only), which the
  panel uses; promoting to `READY` applies any pending draft first, so the
  published content always lives in `text`. This skill never calls it —
  marking a comment approved is a human decision.

Never call `applyCommentDraft` from this skill — it publishes the draft into the
live `text` field, which is a human decision, not something to automate.
If you're asked to review/fix an existing draft rather than write a new
one, that's still just another `submit` call (overwrites the draft in
place); status stays `DRAFT`.

## Law data

`app/assets/parsed_zakon.json` is a flat list of `{chapter, chlan,
paragraph, sr, ru, isTitle}` records — one per paragraph/definition item of
the law, already split exactly the way the app's law viewer
(`app/lib/zakon/zakon.dart`) and the `zakon?chapter=..&chlan=..&paragraph=..`
route address them. `scripts/comments_cli.py search-law` is a thin
keyword/`chlan` filter over this file — there is no other index to build.

The server has its own half-finished, disconnected attempt at this
(`saobracaj_server/saobracaj-ai/.../LawParser.kt`,
`SaobracajGenerator.kt`, `subcategoriesChapters.kt`) — an OpenAI-backed
generator with a `TODO()` in the middle of it, not wired into any GraphQL
endpoint. It's dead code, safe to ignore; this skill does the same job
client-side without needing OpenAI credentials or server changes.
