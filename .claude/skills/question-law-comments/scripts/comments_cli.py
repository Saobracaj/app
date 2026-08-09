#!/usr/bin/env python3
"""
CLI for the "question-law-comments" skill.

Talks to the Saobraćaj GraphQL API (the Rust backend at
`api.saobracaj.gleb.at`) and to the bundled question/law JSON assets so that an
agent can generate RU/SR comments (with links to the law) for exam questions
without ever loading the full 1.4 MB questions file or the ~4000-entry law file
into its own context.

Auth needs a real account **with the `edit_comments` permission** — every write
here is an editor action, and the backend guards it (a throwaway sign-up will
not do). Put the credentials in the environment:

    SAOBRACAJ_COMMENTS_EMAIL=<editor account e-mail>
    SAOBRACAJ_COMMENTS_PASSWORD=<its password>

The script logs in once and caches the refresh token at
~/.saobracaj_comments/auth.json (override with SAOBRACAJ_COMMENTS_TOKEN_FILE);
later runs mint short-lived access tokens from it and only fall back to a
password login when the refresh token has expired. Override the endpoint with
SAOBRACAJ_GRAPHQL_URL if the API ever moves.

Subcommands (see --help on each):
  auth                       make sure a valid access token exists
  queue [--limit N] [--category ID] [--subcategory ID] [--status ...] [--lang ru|sr]
  show ID [ID ...]
  search-law KEYWORD [KEYWORD ...] [--chlan N] [--limit N]
  submit ID (--file PATH | --stdin) [--lang ru|sr]
  status ID [ID ...]
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_SERVER_URL = "https://api.saobracaj.gleb.at/graphql"
SERVER_URL = os.environ.get("SAOBRACAJ_GRAPHQL_URL", DEFAULT_SERVER_URL)

TOKEN_FILE = Path(
    os.environ.get("SAOBRACAJ_COMMENTS_TOKEN_FILE", str(Path.home() / ".saobracaj_comments" / "auth.json"))
)

# Repo-relative asset paths (this file lives at app/.claude/skills/question-law-comments/scripts/)
APP_ROOT = Path(__file__).resolve().parents[4]
QUESTIONS_PATH = APP_ROOT / "assets" / "allQuestions.json"
QUESTIONS_RU_PATH = APP_ROOT / "assets" / "allQuestions_ru.json"
CATEGORIES_PATH = APP_ROOT / "assets" / "categories.json"
ZAKON_PATH = APP_ROOT / "assets" / "parsed_zakon.json"


# --------------------------------------------------------------------------
# GraphQL transport
# --------------------------------------------------------------------------

def gql(query, variables=None, token=None):
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(SERVER_URL, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        data = json.loads(e.read())
    if data.get("errors"):
        raise RuntimeError(f"GraphQL error: {data['errors']}")
    return data["data"]


# --------------------------------------------------------------------------
# Auth (self-registering, self-refreshing)
# --------------------------------------------------------------------------

def _load_cache():
    if TOKEN_FILE.exists():
        return json.loads(TOKEN_FILE.read_text())
    return {}


def _save_cache(cache):
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(json.dumps(cache, indent=2))
    TOKEN_FILE.chmod(0o600)


def _jwt_exp(token):
    import base64
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload)).get("exp", 0)


def _credentials():
    email = os.environ.get("SAOBRACAJ_COMMENTS_EMAIL")
    password = os.environ.get("SAOBRACAJ_COMMENTS_PASSWORD")
    if not (email and password):
        print(
            "error: no editor credentials.\n"
            "  Every mutation here needs an account with the `edit_comments` permission —\n"
            "  set SAOBRACAJ_COMMENTS_EMAIL and SAOBRACAJ_COMMENTS_PASSWORD (ask the operator).",
            file=sys.stderr,
        )
        sys.exit(2)
    return email, password


def _login():
    email, password = _credentials()
    try:
        tokens = gql(
            "mutation($e: String!, $p: String!) { login(email: $e, password: $p) "
            "{ accessToken refreshToken } }",
            {"e": email, "p": password},
        )["login"]
    except RuntimeError as e:
        print(f"error: login as {email} failed ({e}).\n"
              "  Check SAOBRACAJ_COMMENTS_EMAIL / SAOBRACAJ_COMMENTS_PASSWORD with the operator.",
              file=sys.stderr)
        sys.exit(2)
    return {
        "email": email,
        "access_token": tokens["accessToken"],
        "refresh_token": tokens["refreshToken"],
    }


def get_access_token():
    """Returns a valid access token, refreshing or logging in as needed."""
    email, _ = _credentials()  # fail fast with a readable message, before any request
    cache = _load_cache()

    # A cached token from a different account (or from the legacy server) must
    # not be reused silently.
    if cache.get("email") != email:
        cache = {}

    access = cache.get("access_token")
    if access and _jwt_exp(access) > time.time() + 30:
        return access

    refresh = cache.get("refresh_token")
    if refresh:
        try:
            data = gql("mutation($r: String!) { refreshToken(refreshToken: $r) "
                       "{ accessToken refreshToken } }", {"r": refresh})
            tokens = data["refreshToken"]
            cache["access_token"] = tokens["accessToken"]
            cache["refresh_token"] = tokens["refreshToken"]
            _save_cache(cache)
            return cache["access_token"]
        except Exception:
            pass  # refresh token expired/revoked -> log in again

    cache = _login()
    _save_cache(cache)
    return cache["access_token"]


def cmd_auth(args):
    get_access_token()
    print(f"OK, account: {_load_cache().get('email')}")


# --------------------------------------------------------------------------
# Local asset helpers
# --------------------------------------------------------------------------

def _load_questions():
    return json.loads(QUESTIONS_PATH.read_text())


def _load_questions_ru_by_id():
    ru = json.loads(QUESTIONS_RU_PATH.read_text())
    return {q["qId"]: q for q in ru}


def _load_categories():
    return json.loads(CATEGORIES_PATH.read_text())


def _subcategory_name(categories, subcategory_id):
    for cat in categories:
        for sub in cat.get("subcategories", []):
            if sub["Id"] == subcategory_id:
                return cat["name"], sub["Description"]
    return None, None


# --------------------------------------------------------------------------
# queue: which question ids still need a comment
# --------------------------------------------------------------------------

def _fragment_state(comment, lang):
    """Where `lang`'s fragment of this comment currently lives: none/draft/text."""
    def has(block):
        return bool(block) and any(i["lang"] == lang for i in block.get("items", []))

    if has(comment.get("text")):
        return "text"
    if has(comment.get("draft")):
        return "draft"
    return "none"


def cmd_queue(args):
    token = get_access_token()
    comments = gql(
        "{ allQuestionComments { id status draft { items { lang } } text { items { lang } } } }",
        token=token,
    )["allQuestionComments"]
    by_id = {c["id"]: c for c in comments}

    questions = _load_questions()
    if args.category:
        questions = [q for q in questions if q.get("categoryId") == args.category]
    if args.subcategory:
        questions = [q for q in questions if q.get("subcategoryId") == args.subcategory]

    lang = args.lang.upper()
    # For SR the interesting default is "every question that has some RU work
    # already"; for RU it is the untouched backlog.
    status_filter = args.status or ("all" if lang == "SR" else "pending")
    wanted_statuses = {"pending", "draft", "moderation", "ready"} if status_filter == "all" \
        else {status_filter}

    result = []
    for q in questions:
        qid = q["qId"]
        comment = by_id.get(qid)  # no comment row yet == PENDING, nothing in any language
        status = comment["status"] if comment else "PENDING"
        sr_state = _fragment_state(comment or {}, "SR")
        if status.lower() not in wanted_statuses:
            continue
        # The Serbian backlog is per-fragment: a question is done once it carries
        # an SR fragment, whatever the comment's overall status is.
        if lang == "SR" and sr_state != "none":
            continue
        result.append((qid, q.get("categoryId"), q.get("subcategoryId"), status, sr_state))

    # Group by subcategory so a batch shares law context -> fewer law lookups per session.
    result.sort(key=lambda r: (r[1] or "", r[2] or 0, r[0]))

    if args.limit:
        result = result[: args.limit]

    for qid, cat, sub, status, sr_state in result:
        print(f"{qid}\tcat={cat}\tsub={sub}\t{status}\tsr={sr_state}")
    print(f"# {len(result)} question(s) matched", file=sys.stderr)


# --------------------------------------------------------------------------
# show: compact question payload for the LLM to read
# --------------------------------------------------------------------------

def cmd_show(args):
    questions = {q["qId"]: q for q in _load_questions()}
    ru_by_id = _load_questions_ru_by_id()
    categories = _load_categories()
    token = get_access_token()

    for qid in args.ids:
        qid = int(qid)
        q = questions.get(qid)
        if not q:
            print(f"=== {qid}: NOT FOUND in allQuestions.json ===")
            continue

        cat_name, sub_desc = _subcategory_name(categories, q.get("subcategoryId"))
        ru = ru_by_id.get(qid)

        try:
            existing = gql("query($id: Int!) { questionComment(id: $id) { status "
                           "draft { items { lang text } } text { items { lang text } } } }",
                           {"id": qid}, token=token)["questionComment"]
        except Exception:
            existing = None

        print(f"=== question {qid} ===")
        print(f"category: {q.get('categoryId')} ({cat_name})")
        print(f"subcategory: {q.get('subcategoryId')} ({sub_desc})")
        print(f"text_sr: {q['Text']}")
        if ru:
            print(f"text_ru_hint: {ru['Text']}")
        print(f"choices_required: {q.get('ChoicesReq')}")
        for i, c in enumerate(q["Choices"]):
            mark = "CORRECT" if c.get("isCorrect") else "wrong"
            print(f"  [{i}] ({mark}) {c['Text']}")
        if q.get("HasImage"):
            print("has_image: true (image not available through this CLI)")
        if existing:
            print(f"comment_status: {existing['status']}")
            # Both languages are printed: the RU text is the source an SR
            # adaptation is written from, and vice versa it shows what exists.
            # An applied comment stores the same text in `draft` and `text`;
            # printing it twice only wastes context, so the copy is skipped.
            published = {
                t["lang"]: t["text"]
                for t in (existing.get("text") or {}).get("items", [])
            }
            for block, label in (("draft", "existing_draft"), ("text", "existing_published")):
                for t in (existing.get(block) or {}).get("items", []):
                    if block == "draft" and published.get(t["lang"]) == t["text"]:
                        continue
                    text = t["text"] if args.full else t["text"][:300]
                    print(f"{label}_{t['lang'].lower()}: {text}")
        print()


# --------------------------------------------------------------------------
# search-law: keyword search over parsed_zakon.json
# --------------------------------------------------------------------------

_ZAKON_CACHE = None


def _load_zakon():
    global _ZAKON_CACHE
    if _ZAKON_CACHE is None:
        _ZAKON_CACHE = json.loads(ZAKON_PATH.read_text())
    return _ZAKON_CACHE


def cmd_search_law(args):
    data = _load_zakon()
    keywords = [k.lower() for k in args.keywords]

    if args.chlan:
        matches = [e for e in data if e.get("chlan") == str(args.chlan)]
    else:
        matches = []
        for e in data:
            haystack = (e.get("sr", "") + " " + e.get("ru", "")).lower()
            if all(k in haystack for k in keywords):
                matches.append(e)

    matches = matches[: args.limit]
    if not matches:
        print("# no matches", file=sys.stderr)
        return

    for e in matches:
        chapter, chlan, paragraph = e.get("chapter"), e.get("chlan"), e.get("paragraph")
        params = []
        if chapter:
            params.append(f"chapter={chapter}")
        if chlan:
            params.append(f"chlan={chlan}")
        if paragraph is not None:
            params.append(f"paragraph={paragraph}")
        link = "zakon?" + "&".join(params)
        print(f"[{link}]")
        print(f"  sr: {e['sr']}")
        print(f"  ru: {e['ru']}")
        print()


# --------------------------------------------------------------------------
# submit: save a RU markdown comment as a draft (pending human review)
# --------------------------------------------------------------------------

def cmd_submit(args):
    token = get_access_token()

    if args.file:
        text = Path(args.file).read_text()
    else:
        text = sys.stdin.read()
    text = text.strip()
    if not text:
        print("error: empty comment text", file=sys.stderr)
        sys.exit(1)

    lang = args.lang.upper()

    current = gql("query($id: Int!) { questionComment(id: $id) { status "
                  "draft { items { lang text } } text { items { lang text } } } }",
                  {"id": args.id}, token=token)["questionComment"]
    status = current["status"] if current else "PENDING"
    draft_items = {t["lang"]: t["text"]
                   for t in ((current or {}).get("draft") or {}).get("items", [])}
    published_items = {t["lang"]: t["text"]
                       for t in ((current or {}).get("text") or {}).get("items", [])}

    # A READY/MODERATION comment is protected per *language*: adding the missing
    # SR fragment to a published RU comment is the normal Serbian workflow and
    # touches nothing that a human already approved.
    if not args.force and status in ("READY", "MODERATION"):
        if lang in draft_items or lang in published_items:
            print(f"refusing to overwrite comment {args.id}: status is {status} "
                  f"and a {lang} fragment already exists (pass --force to override)",
                  file=sys.stderr)
            sys.exit(1)

    # `applyCommentDraft` replaces the published text with the draft *wholesale*,
    # so a draft holding only SR would drop an already published RU fragment the
    # moment a human applies it. Copy any published fragment the draft is missing
    # back into the draft first, and the apply stays additive.
    for other_lang, other_text in published_items.items():
        if other_lang != lang and other_lang not in draft_items:
            gql(
                "mutation($id: Int!, $draft: String!, $lang: Language!) "
                "{ saveCommentDraft(id: $id, draft: $draft, language: $lang) { id } }",
                {"id": args.id, "draft": other_text, "lang": other_lang},
                token=token,
            )
            print(f"carried the published {other_lang} fragment into the draft")

    # saveCommentDraft replaces only the fragment of the given language; the
    # other language's draft fragment is preserved server-side.
    result = gql(
        "mutation($id: Int!, $draft: String!, $lang: Language!) "
        "{ saveCommentDraft(id: $id, draft: $draft, language: $lang) { id status } }",
        {"id": args.id, "draft": text, "lang": lang},
        token=token,
    )["saveCommentDraft"]
    print(f"saved: id={result['id']} status={result['status']} lang={lang}")


def cmd_status(args):
    token = get_access_token()
    for qid in args.ids:
        data = gql("query($id: Int!) { questionComment(id: $id) { status "
                   "draft { items { lang } } text { items { lang } } } }",
                   {"id": int(qid)}, token=token)["questionComment"]
        if not data:
            print(f"{qid}\tPENDING\tru=none\tsr=none")
            continue
        print(f"{qid}\t{data['status']}\tru={_fragment_state(data, 'RU')}\t"
              f"sr={_fragment_state(data, 'SR')}")


# --------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("auth", help="ensure a valid access token exists")
    p.set_defaults(func=cmd_auth)

    p = sub.add_parser("queue", help="list question ids that still need a comment")
    p.add_argument("--limit", type=int, default=20)
    p.add_argument("--category", help="filter by categoryId (string, e.g. '25')")
    p.add_argument("--subcategory", type=int, help="filter by subcategoryId")
    p.add_argument("--status", default=None,
                   choices=["pending", "draft", "moderation", "ready", "all"],
                   help="comment status filter (default: 'pending' for --lang ru, 'all' for --lang sr)")
    p.add_argument("--lang", default="ru", choices=["ru", "sr"],
                   help="which language's backlog to list; 'sr' lists questions with no SR fragment yet")
    p.set_defaults(func=cmd_queue)

    p = sub.add_parser("show", help="print a compact view of one or more questions")
    p.add_argument("ids", nargs="+")
    p.add_argument("--full", action="store_true",
                   help="print existing comments in full instead of the first 300 "
                        "characters (needed when adapting an RU comment into SR)")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("search-law", help="keyword search over parsed_zakon.json")
    p.add_argument("keywords", nargs="*")
    p.add_argument("--chlan", type=int, help="dump all paragraphs of this article instead of keyword search")
    p.add_argument("--limit", type=int, default=8)
    p.set_defaults(func=cmd_search_law)

    p = sub.add_parser("submit", help="save a markdown comment as a draft (pending review)")
    p.add_argument("id", type=int)
    p.add_argument("--file", help="path to a file with the markdown text")
    p.add_argument("--stdin", action="store_true", help="read the markdown text from stdin")
    p.add_argument("--lang", default="ru", choices=["ru", "sr"],
                   help="language of the fragment being saved (default: ru)")
    p.add_argument("--force", action="store_true", help="overwrite even if status is READY/MODERATION")
    p.set_defaults(func=cmd_submit)

    p = sub.add_parser("status", help="print current comment status for question ids")
    p.add_argument("ids", nargs="+")
    p.set_defaults(func=cmd_status)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
