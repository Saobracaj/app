#!/usr/bin/env python3
"""
CLI for the "question-law-comments" skill.

Talks to the Saobraćaj GraphQL server and to the bundled question/law JSON
assets so that an agent can generate RU comments (with links to the law) for
exam questions without ever loading the full 1.4 MB questions file or the
~4000-entry law file into its own context.

Auth is fully self-contained: on first use the script signs up a disposable
dev account (BASIC permission is all `comments`/`draft` need) and caches its
refresh token at ~/.saobracaj_comments/auth.json (override with
SAOBRACAJ_COMMENTS_TOKEN_FILE). Later runs mint short-lived access tokens
from the cached refresh token automatically. No operator interaction needed.

Subcommands (see --help on each):
  auth                       make sure a valid access token exists, print nothing on success
  queue [--limit N] [--category ID] [--subcategory ID] [--status ...]
  show ID [ID ...]
  search-law KEYWORD [KEYWORD ...] [--chlan N] [--limit N]
  submit ID (--file PATH | --stdin)
  status ID [ID ...]
"""
import argparse
import json
import os
import random
import string
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_SERVER_URL = "https://saobracaj-serveer-69637270851.europe-west3.run.app/graphql"
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


def _sign_up_new_account():
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=8))
    email = f"autopilot-comments+{int(time.time())}-{suffix}@gleb.at"
    password = "".join(random.choices(string.ascii_letters + string.digits, k=24)) + "!Aa1"
    data = gql(
        "query($e: String!, $p: String!) { signUp(email: $e, password: $p) { accessToken refreshToken } }",
        {"e": email, "p": password},
    )
    tokens = data["signUp"]
    return {
        "email": email,
        "access_token": tokens["accessToken"],
        "refresh_token": tokens["refreshToken"],
    }


def get_access_token():
    """Returns a valid access token, creating/refreshing credentials as needed."""
    cache = _load_cache()

    access = cache.get("access_token")
    if access and _jwt_exp(access) > time.time() + 30:
        return access

    refresh = cache.get("refresh_token")
    if refresh:
        try:
            data = gql("query($r: String!) { refreshToken(refreshToken: $r) { accessToken refreshToken } }",
                        {"r": refresh})
            tokens = data["refreshToken"]
            cache["access_token"] = tokens["accessToken"]
            cache["refresh_token"] = tokens["refreshToken"]
            _save_cache(cache)
            return cache["access_token"]
        except Exception:
            pass  # fall through to re-registration

    cache = _sign_up_new_account()
    _save_cache(cache)
    return cache["access_token"]


def cmd_auth(args):
    token = get_access_token()
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

def cmd_queue(args):
    token = get_access_token()
    comments = gql("{ comments { id status } }", token=token)["comments"]
    status_by_id = {c["id"]: c["status"] for c in comments}

    questions = _load_questions()
    if args.category:
        questions = [q for q in questions if q.get("categoryId") == args.category]
    if args.subcategory:
        questions = [q for q in questions if q.get("subcategoryId") == args.subcategory]

    wanted_statuses = {"pending"} if args.status == "pending" else \
        {"pending", "draft", "moderation", "ready"} if args.status == "all" else {args.status}

    result = []
    for q in questions:
        qid = q["qId"]
        status = status_by_id.get(qid, "PENDING")  # no Comment doc yet == PENDING
        if status.lower() in wanted_statuses:
            result.append((qid, q.get("categoryId"), q.get("subcategoryId"), status))

    # Group by subcategory so a batch shares law context -> fewer law lookups per session.
    result.sort(key=lambda r: (r[1] or "", r[2] or 0, r[0]))

    if args.limit:
        result = result[: args.limit]

    for qid, cat, sub, status in result:
        print(f"{qid}\tcat={cat}\tsub={sub}\t{status}")
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
            existing = gql("query($id: Long!) { comment(id: $id) { status draft { text { lang text } } "
                            "text { text { lang text } } } }", {"id": qid}, token=token)["comment"]
        except Exception as e:
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
            if existing.get("draft"):
                for t in existing["draft"]["text"]:
                    if t["lang"] == "RU":
                        print(f"existing_draft_ru: {t['text'][:300]}")
            if existing.get("text"):
                for t in existing["text"]["text"]:
                    if t["lang"] == "RU":
                        print(f"existing_published_ru: {t['text'][:300]}")
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

    if not args.force:
        current = gql("query($id: Long!) { comment(id: $id) { status } }", {"id": args.id}, token=token)["comment"]
        if current["status"] in ("READY", "MODERATION"):
            print(f"refusing to overwrite comment {args.id}: status is {current['status']} "
                  f"(pass --force to override)", file=sys.stderr)
            sys.exit(1)

    result = gql(
        "mutation($id: Long!, $draft: String!) { draft(id: $id, draft: $draft) { id status } }",
        {"id": args.id, "draft": text},
        token=token,
    )["draft"]
    print(f"saved: id={result['id']} status={result['status']}")


def cmd_status(args):
    token = get_access_token()
    for qid in args.ids:
        data = gql("query($id: Long!) { comment(id: $id) { status } }", {"id": int(qid)}, token=token)["comment"]
        print(f"{qid}\t{data['status']}")


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
    p.add_argument("--status", default="pending", choices=["pending", "draft", "moderation", "ready", "all"])
    p.set_defaults(func=cmd_queue)

    p = sub.add_parser("show", help="print a compact view of one or more questions")
    p.add_argument("ids", nargs="+")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("search-law", help="keyword search over parsed_zakon.json")
    p.add_argument("keywords", nargs="*")
    p.add_argument("--chlan", type=int, help="dump all paragraphs of this article instead of keyword search")
    p.add_argument("--limit", type=int, default=8)
    p.set_defaults(func=cmd_search_law)

    p = sub.add_parser("submit", help="save a RU markdown comment as a draft (pending review)")
    p.add_argument("id", type=int)
    p.add_argument("--file", help="path to a file with the markdown text")
    p.add_argument("--stdin", action="store_true", help="read the markdown text from stdin")
    p.add_argument("--force", action="store_true", help="overwrite even if status is READY/MODERATION")
    p.set_defaults(func=cmd_submit)

    p = sub.add_parser("status", help="print current comment status for question ids")
    p.add_argument("ids", nargs="+")
    p.set_defaults(func=cmd_status)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
