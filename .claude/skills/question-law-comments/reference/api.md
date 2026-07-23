# API cheatsheet

You normally don't need any of this — `scripts/comments_cli.py` wraps it
all. Read this only if you need to debug the CLI or extend it.

Server: `saobracaj_server` (Kotlin/Ktor/KGraphQL), endpoint `/graphql`,
default deployed instance:
`https://saobracaj-serveer-69637270851.europe-west3.run.app/graphql`.
Resolvers live in
`saobracaj_server/saobracaj/saobracaj/src/main/kotlin/presentation/SaobracajPresentation.kt`.

## Auth

- `signUp(email, password)` (public query) -> `{ accessToken, refreshToken }`.
  Any never-before-used email works; no confirmation step in this deploy
  (`confirmEmailBeforeAuth = false`). New accounts get `BASIC` permission,
  which is all the comment endpoints require.
- `refreshToken(refreshToken)` (public query) -> new `{ accessToken,
  refreshToken }` pair. Access tokens are short-lived (~15 min); refresh
  tokens last ~30 days.
- Send `Authorization: Bearer <accessToken>` on every subsequent call.
- Errors come back as HTTP 200 with a top-level `errors` array (e.g. `Token
  expired`), not as an HTTP error status — always check for `errors` in the
  response body.

## Comment id == question id

A `Comment` document's `id` (`Long`) is the same value as the question's
`qId`/`qcId` in `app/assets/allQuestions.json`. Comment docs are created
lazily: querying/mutating an id that has no document yet auto-creates one
with `status = PENDING`.

## Queries/mutations used by this skill

```graphql
query { comments { id status } }                       # cheap bulk status list, used by `queue`
query($id: Long!) { comment(id: $id) { status draft { text { lang text } } text { text { lang text } } } }
mutation($id: Long!, $draft: String!) { draft(id: $id, draft: $draft) { id status } }
```

`draft(id, text)` always writes the **Russian** text item (language
defaults server-side to `RU`; there's no way to pass a language from this
mutation's current signature). It flips `status` from `PENDING` to `DRAFT`
the first time; later calls just overwrite the draft text in place.

## `CommentStatus` state machine

```
PENDING  -- draft() --> DRAFT -- applyDraft() --> MODERATION -- (human, in the Angular panel) --> READY
```

- `PENDING`: no draft/text yet.
- `DRAFT`: someone saved draft text, not yet applied. **This is where
  `submit` leaves everything — it never calls `applyDraft`.** A human
  reviews drafts in the Angular admin panel (`markdown-editor` /
  `question-preview` components) and applies them from there.
- `MODERATION`: draft was applied over an existing published text and is
  awaiting re-review.
- `READY`: approved, live in the app-facing `text` field.

Never call `applyDraft` from this skill — publishing is a human decision.
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
