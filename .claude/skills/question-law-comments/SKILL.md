---
name: question-law-comments
description: Use when asked to write, review, or batch-generate RU comments (explanations with law citations) for Saobraćaj exam questions, or to check/triage which questions still lack a comment. Talks to the live GraphQL server and to the bundled app/assets JSON files; never touches app source code.
---

# Question law comments

Generates Russian-language explanations (with links into the Serbian traffic
law) for driving-exam questions, in the same style as the ~35 already
human-approved comments, and saves them to the server as **drafts** (status
`DRAFT`, shown as "Черновик" in the Angular panel). This skill never calls
`applyDraft`; a human always reviews the draft in the Angular admin panel
and applies/publishes it themselves. See `reference/api.md` for the exact
`CommentStatus` state machine — `DRAFT` is *not* the same thing as the
literal `PENDING` enum value (those are two different, unrelated states).

There are ~1701 questions and only a few dozen already have an approved
comment — most of the work is a large, repetitive backlog. Process it in
small batches (see "Segmentation plan" below), not all at once.

## Setup (one-time, already done, no action needed)

Auth is fully self-contained. `scripts/comments_cli.py auth` (called
automatically by every other subcommand) signs up a disposable dev account
on first use and caches its refresh token at
`~/.saobracaj_comments/auth.json`. Nothing to configure, no operator
token needed. Override the server with `SAOBRACAJ_GRAPHQL_URL` if it ever
moves; override the cache path with `SAOBRACAJ_COMMENTS_TOKEN_FILE`.

## Workflow for a batch of N questions (N = 1 to ~5)

Run everything through `scripts/comments_cli.py` — never open
`assets/allQuestions.json` (1.4 MB) or `assets/parsed_zakon.json` (~4000
entries) directly with the Read tool, that burns context for nothing.

1. **Pick the batch.**
   ```
   python3 scripts/comments_cli.py queue --limit 5
   ```
   Prints `qId  cat=..  sub=..  STATUS` for questions still needing a
   comment, grouped by subcategory (so a batch usually shares the same law
   context). Narrow with `--category` / `--subcategory` if you want to work
   through one topic at a time. Only `PENDING` questions are real backlog;
   leave `DRAFT`/`MODERATION`/`READY` alone unless explicitly asked to
   revise them.

2. **Read the questions.**
   ```
   python3 scripts/comments_cli.py show 7973 7974 7977
   ```
   Prints, per question: category/subcategory names, the Serbian question
   text and choices with `isCorrect` flags marked, an RU translation hint
   (translation only — the choices themselves stay Serbian, that's the exam
   language), whether it has an image (images aren't fetched by this CLI —
   if `has_image: true` and the image matters, read the question text
   carefully first; only pull in extra help if genuinely stuck), and any
   existing draft/published text for context.

3. **Find the exact law citation.** Don't guess the chlan/paragraph —
   look it up:
   ```
   python3 scripts/comments_cli.py search-law седиште појасева
   python3 scripts/comments_cli.py search-law --chlan 7   # dump a whole article, e.g. the definitions article
   ```
   Keyword search is a case-insensitive AND match over the Serbian +
   Russian text of every law paragraph (`app/assets/parsed_zakon.json`).
   Most "definitions" questions (subcategory whose name contains "Значење
   израза") map to **chlan 7** (see `reference/examples.md`), which is a
   long list of term definitions — search within it directly.

4. **Write the comment.** Russian markdown, following
   `reference/style-guide.md` and the worked examples in
   `reference/examples.md`. Every legal claim needs a
   `[текст](zakon?chapter=X&chlan=Y&paragraph=Z)` link built from the exact
   fields `search-law` printed — never hand-roll the query string.

5. **Save as a draft.**
   ```
   python3 scripts/comments_cli.py submit 7973 --file /tmp/7973.md
   ```
   or pipe text via `--stdin`. This calls the `draft` mutation only (never
   `applyDraft`), so the comment lands in status `DRAFT` ("Черновик" in the
   Angular panel) — unpublished, waiting for a human to read it. Calling
   `applyDraft` instead would immediately copy the draft into the live
   `text` field (the field the Angular panel treats as the officially
   published comment), i.e. publish it unreviewed — the opposite of what we
   want. A human applies the draft themselves from the Angular panel once
   they've reviewed it. It refuses to overwrite a `READY`/`MODERATION`
   comment unless you pass `--force`.

6. **Spot-check.**
   ```
   python3 scripts/comments_cli.py status 7973
   ```

## Segmentation plan (how to burn through the backlog efficiently)

- Work in batches of **3-5 questions per `queue`/`show` call**, sharing one
  `search-law` context when they're in the same subcategory — this is the
  main token saver, most of the cost is the law lookup, not the question
  text.
- Do **one full session per Asana subtask/task run**: `queue` a batch,
  produce and `submit` all of them, then stop. Don't try to clear the whole
  backlog in one sitting — there are ~1600 pending questions.
- Prioritize by subcategory whose name is "Значење израза..." (definitions)
  first — they map almost 1:1 onto chlan 7 paragraphs and are fast/cheap to
  do correctly. Then move to procedural subcategories (right of way,
  signaling, etc.), which need more careful `search-law` keyword work per
  question.
- Skip (don't touch) any question where `show` reports `has_image: true`
  and the correct answer genuinely depends on reading the image content —
  this CLI can't display images. Flag those for a human or for a
  vision-capable follow-up pass instead of guessing.
- Track progress via `queue --status all` if you need to audit what's been
  done vs. still pending; the server itself is the source of truth, no
  separate local progress file is needed (the `comments` GraphQL query is
  cheap — id + status only).

## Files

- `scripts/comments_cli.py` — the only thing you should run; stdlib-only
  Python 3, no dependencies to install.
- `reference/style-guide.md` — distilled conventions (bold/italics/links,
  common paragraph shapes) from the approved comments.
- `reference/examples.md` — five worked question -> comment examples,
  pulled from the live, human-approved (`READY`) comments.
- `reference/api.md` — GraphQL schema cheatsheet (queries/mutations,
  `CommentStatus` meaning, why `submit` never calls `applyDraft`).
