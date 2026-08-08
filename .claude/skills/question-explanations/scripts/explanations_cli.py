#!/usr/bin/env python3
"""CLI helper for generating, validating and publishing question explanations
(the pre-generated "Ask AI" documents).

Stdlib-only. Reads bundled app assets and konspekt sources; writes nothing
except what you ask for.

Explanations are **stored in the backend database** (table
`saobracaj_question_explanations`, one row per (question, language)) and served
to the app over GraphQL (`questionExplanation` / `questionExplanations`,
premium `ask_ai` feature). The authored JSON is kept in the repo under
`explanation_content/<categoryId>/<qId>.json` (Russian) and
`<qId>.sr.json` (Serbian) as the editable source; `publish` uploads a whole
category to the database.

Subcommands:
  queue CATEGORY_ID [--lang ru|sr]     question ids still lacking a local file
  context QID [QID ...] [--lang ...]   everything needed to author one
                                       explanation: the question + the konspekt
                                       blocks mapped to it
  search-law KEYWORD [...] [--chlan N] keyword search over parsed_zakon.json
  validate TARGET [--lang ...]         validate one file or a whole category
  publish CATEGORY_ID [--lang ...]     validate, then upsert every explanation
      [--qid N] [--dry-run]            of the category into the database
  published [--category ID] [--lang]   what the database currently serves

Database access (publish/published) goes through SSH to the VPS and `psql`
inside the Postgres container — the same transport as the konspekt CLI.
Credentials come from the environment; the repo holds no secrets:

  KONSPEKT_VPS_HOST       VPS hostname/IP                 (required)
  KONSPEKT_VPS_USER       SSH user                        (default: ubuntu)
  KONSPEKT_VPS_PASSWORD   SSH password; omit to use key auth
  KONSPEKT_DB_CONTAINER   Postgres container name         (default: app-db-1)
  KONSPEKT_PG_USER        Postgres role                   (default: saobracaj)
  KONSPEKT_PG_DB          database name                   (default: saobracaj_backend)
"""
import argparse
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[4]
ASSETS = APP_DIR / "assets"
# Authored explanation sources. Not a Flutter asset directory: the app
# downloads explanations from the backend, these files are the editable
# originals kept in git.
CONTENT_DIR = APP_DIR / "explanation_content"
KONSPEKT_DIR = APP_DIR / "konspekt_content"

LANGS = ("ru", "sr")


def load_json(name):
    with open(ASSETS / name, encoding="utf-8") as f:
        return json.load(f)


def load_questions():
    return load_json("allQuestions.json")


def load_ru_hints():
    return {q["qId"]: q for q in load_json("allQuestions_ru.json")}


def source_path(category_id, qid, lang):
    suffix = ".json" if lang == "ru" else f".{lang}.json"
    return CONTENT_DIR / str(category_id) / f"{qid}{suffix}"


def category_questions(category_id):
    qs = [q for q in load_questions() if q["categoryId"] == category_id]
    if not qs:
        sys.exit(f"no questions found for category {category_id!r}")
    return qs


# ------------------------------------------------------------------- queue ---

def cmd_queue(args):
    qs = category_questions(args.category_id)
    qs.sort(key=lambda q: (q["subcategoryId"], q["qId"]))
    missing = [q for q in qs if not source_path(args.category_id, q["qId"], args.lang).exists()]
    for q in missing:
        img = " IMG" if q["HasImage"] else ""
        print(f"{q['qId']}\tsub={q['subcategoryId']}{img}")
    print(
        f"# {len(missing)} of {len(qs)} questions of category {args.category_id} "
        f"have no {args.lang} explanation yet",
        file=sys.stderr,
    )


# ----------------------------------------------------------------- context ---

def _konspekt_blocks_for(category_id, qid, lang):
    """(section_id, block_markdown) pairs of every konspekt block mapped to qid."""
    path = KONSPEKT_DIR / f"{category_id}.json"
    if not path.exists():
        return None
    k = json.loads(path.read_text(encoding="utf-8"))
    hits = []
    for s in k.get("sections", []):
        for b in s.get("blocks") or []:
            if qid in (b.get("questionIds") or []):
                content = (b.get("content") or {})
                text = content.get(lang) or content.get("ru") or ""
                hits.append((s["id"], text))
    return hits


def cmd_context(args):
    questions = {q["qId"]: q for q in load_questions()}
    ru = load_ru_hints()
    cats = load_json("categories.json")

    def sub_desc(sub_id):
        for c in cats:
            for s in c["subcategories"]:
                if s["Id"] == sub_id:
                    return s["Description"].strip()
        return ""

    for raw in args.ids:
        qid = int(raw)
        q = questions.get(qid)
        if not q:
            print(f"=== {qid}: NOT FOUND ===")
            continue
        cat = q["categoryId"]
        print(f"=== question {qid} (category {cat}, sub {q['subcategoryId']}: {sub_desc(q['subcategoryId'])}) ===")
        if q["HasImage"]:
            print(f"image: assets/img/{qid}.jpeg (Read it if the answer depends on the picture)")
        if q["ChoicesReq"] > 1:
            print(f"choose: {q['ChoicesReq']}")
        print(f"SR: {q['Text']}")
        hint = ru.get(qid)
        if hint:
            print(f"RU: {hint['Text']}")
        for ch in q["Choices"]:
            mark = "✓" if ch["isCorrect"] else "·"
            print(f" {mark} {ch['Text']}")
        blocks = _konspekt_blocks_for(cat, qid, args.lang)
        if blocks is None:
            print("-- no konspekt for this category --")
        elif not blocks:
            print("-- no konspekt block maps this question --")
        for sid, text in blocks or []:
            print(f"-- konspekt block (link: konspekt?category={cat}&section={sid}) --")
            print(text)
        print()


# -------------------------------------------------------------- search-law ---

_ZAKON_CACHE = None


def _load_zakon():
    global _ZAKON_CACHE
    if _ZAKON_CACHE is None:
        _ZAKON_CACHE = json.loads((ASSETS / "parsed_zakon.json").read_text(encoding="utf-8"))
    return _ZAKON_CACHE


def cmd_search_law(args):
    data = _load_zakon()
    keywords = [k.lower() for k in args.keywords]

    if args.chlan:
        matches = [e for e in data if e.get("chlan") == str(args.chlan)]
    else:
        matches = [
            e
            for e in data
            if all(k in (e.get("sr", "") + " " + e.get("ru", "")).lower() for k in keywords)
        ]

    matches = matches[: args.limit]
    if not matches:
        print("# no matches", file=sys.stderr)
        return
    for e in matches:
        params = []
        if e.get("chapter"):
            params.append(f"chapter={e['chapter']}")
        if e.get("chlan"):
            params.append(f"chlan={e['chlan']}")
        if e.get("paragraph") is not None:
            params.append(f"paragraph={e['paragraph']}")
        print(f"[zakon?{'&'.join(params)}]")
        print(f"  sr: {e['sr']}")
        print(f"  ru: {e['ru']}")
        print()


# ---------------------------------------------------------------- validate ---

REQUIRED_KEYS = {"questionId", "lang", "version", "summary", "whyCorrect", "whyOthersWrong", "memoryHook", "sources"}
MD_LINK_RE = re.compile(r"\]\(([^)]+)\)")
SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def _parse_query(link):
    """'zakon?chlan=7&paragraph=79' -> ('zakon', {'chlan': '7', ...}) or None."""
    m = re.match(r"^(zakon|konspekt|question)\?([A-Za-z0-9=&_-]+)$", link)
    if not m:
        return None
    params = {}
    for pair in m.group(2).split("&"):
        if "=" not in pair:
            return None
        k, v = pair.split("=", 1)
        params[k] = v
    return m.group(1), params


def _check_link(link, all_qids):
    """Returns an error string, or None when the link resolves."""
    parsed = _parse_query(link)
    if not parsed:
        return f"unrecognized link {link!r} (expected zakon?…, konspekt?… or question?id=…)"
    kind, params = parsed
    if kind == "question":
        if set(params) != {"id"} or not params["id"].isdigit():
            return f"question link {link!r} must be question?id=<qId>"
        if int(params["id"]) not in all_qids:
            return f"link {link!r}: no such question"
        return None
    if kind == "zakon":
        if not set(params) <= {"chapter", "chlan", "paragraph"} or "chlan" not in params:
            return f"zakon link {link!r} must carry chlan (and optionally chapter/paragraph)"
        entries = [e for e in _load_zakon() if e.get("chlan") == params["chlan"]]
        if not entries:
            return f"link {link!r}: no article (chlan) {params['chlan']} in parsed_zakon.json"
        if "paragraph" in params and not any(
            e.get("paragraph") == params["paragraph"] for e in entries
        ):
            return f"link {link!r}: article {params['chlan']} has no paragraph {params['paragraph']}"
        return None
    # konspekt
    if set(params) != {"category", "section"}:
        return f"konspekt link {link!r} must be konspekt?category=<id>&section=<slug>"
    path = KONSPEKT_DIR / f"{params['category']}.json"
    if not path.exists():
        return f"link {link!r}: no konspekt for category {params['category']}"
    k = json.loads(path.read_text(encoding="utf-8"))
    if params["section"] not in {s.get("id") for s in k.get("sections", [])}:
        return f"link {link!r}: konspekt {params['category']} has no section {params['section']!r}"
    return None


def _validate_file(path, lang, questions_by_id, errors):
    label = path.relative_to(APP_DIR) if path.is_relative_to(APP_DIR) else path

    def err(msg):
        errors.append(f"{label}: {msg}")

    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        err(f"invalid JSON ({e})")
        return

    if not isinstance(doc, dict):
        err("document must be a JSON object")
        return
    extra = set(doc) - REQUIRED_KEYS
    if extra:
        err(f"unknown keys {sorted(extra)}")
    missing = REQUIRED_KEYS - set(doc)
    if missing:
        err(f"missing keys {sorted(missing)} (use null for empty whyOthersWrong/memoryHook)")
        return

    name_qid = int(path.name.split(".")[0])
    if doc["questionId"] != name_qid:
        err(f"questionId {doc['questionId']} does not match file name {name_qid}")
    if doc["lang"] != lang:
        err(f"lang {doc['lang']!r} does not match file suffix ({lang})")
    if not (isinstance(doc["version"], int) and doc["version"] >= 1):
        err("version must be a positive int (bump it on every published change)")

    q = questions_by_id.get(name_qid)
    if q is None:
        err("no such question in allQuestions.json")

    summary = doc["summary"]
    if not isinstance(summary, str) or not (20 <= len(summary.strip()) <= 350):
        err("summary must be a 20–350 char string")
    elif "\n" in summary or "](" in summary:
        err("summary must be a plain sentence: no line breaks, no markdown links")

    why = doc["whyCorrect"]
    if not isinstance(why, str) or not (30 <= len(why.strip()) <= 2600):
        err("whyCorrect must be a 30–2600 char markdown string")

    wrong = doc["whyOthersWrong"]
    if wrong is not None and (not isinstance(wrong, str) or not (20 <= len(wrong.strip()) <= 2600)):
        err("whyOthersWrong must be null or a 20–2600 char markdown string")

    hook = doc["memoryHook"]
    if hook is not None and (
        not isinstance(hook, str) or "\n" in hook or not (10 <= len(hook.strip()) <= 300)
    ):
        err("memoryHook must be null or a single 10–300 char line")

    all_qids = set(questions_by_id)
    for field in ("whyCorrect", "whyOthersWrong"):
        text = doc.get(field)
        if isinstance(text, str):
            for m in MD_LINK_RE.finditer(text):
                problem = _check_link(m.group(1), all_qids)
                if problem:
                    err(f"{field}: {problem}")

    sources = doc["sources"]
    if not isinstance(sources, list) or not (1 <= len(sources) <= 4):
        err("sources must be an array of 1–4 entries")
        sources = []
    for i, s in enumerate(sources):
        sp = f"sources[{i}]"
        if not isinstance(s, dict) or set(s) != {"type", "title", "link"}:
            err(f"{sp}: must be an object with exactly type/title/link")
            continue
        if s["type"] not in ("zakon", "konspekt"):
            err(f"{sp}.type: must be 'zakon' or 'konspekt'")
        if not (isinstance(s["title"], str) and 5 <= len(s["title"].strip()) <= 120):
            err(f"{sp}.title: must be a 5–120 char string")
        if not isinstance(s["link"], str) or not s["link"].startswith(f"{s.get('type')}?"):
            err(f"{sp}.link: must start with '{s.get('type')}?'")
        else:
            problem = _check_link(s["link"], all_qids)
            if problem:
                err(f"{sp}.link: {problem}")


def _category_files(category_id, lang):
    directory = CONTENT_DIR / str(category_id)
    if not directory.is_dir():
        return []
    if lang == "ru":
        return sorted(
            p for p in directory.glob("*.json") if "." not in p.name.removesuffix(".json")
        )
    return sorted(directory.glob(f"*.{lang}.json"))


def cmd_validate(args):
    questions_by_id = {q["qId"]: q for q in load_questions()}
    errors = []
    target = Path(args.target)
    if target.is_file():
        lang = "sr" if target.name.endswith(".sr.json") else "ru"
        _validate_file(target, lang, questions_by_id, errors)
        checked = 1
    else:
        files = _category_files(args.target, args.lang)
        if not files:
            sys.exit(f"no {args.lang} explanation files under {CONTENT_DIR / args.target}")
        cat_qids = {q["qId"] for q in category_questions(args.target)}
        for path in files:
            _validate_file(path, args.lang, questions_by_id, errors)
            qid = int(path.name.split(".")[0])
            if qid not in cat_qids:
                errors.append(f"{path}: question {qid} is not in category {args.target}")
        checked = len(files)
        missing = sorted(cat_qids - {int(p.name.split(".")[0]) for p in files})
        if missing:
            print(
                f"note: {len(missing)} of {len(cat_qids)} questions have no {args.lang} "
                f"explanation yet: {missing}"
            )
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        sys.exit(1)
    print(f"OK ({checked} file(s))")


# ---------------------------------------------------------------- database ---
#
# Same transport as the konspekt CLI: there is no direct Postgres port on the
# VPS, so every statement is piped through `ssh <vps> docker exec -i <container>
# psql`. Password auth (when the operator supplies one) goes through SSH_ASKPASS
# rather than a tty helper, which keeps stdin free for the SQL we pipe in.

TABLE_DDL = """
CREATE TABLE IF NOT EXISTS saobracaj_question_explanations (
    question_id INTEGER NOT NULL,
    lang        TEXT NOT NULL,
    version     INTEGER NOT NULL DEFAULT 1,
    document    JSONB NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by  UUID,
    PRIMARY KEY (question_id, lang)
);
"""


def _db_env():
    host = os.environ.get("KONSPEKT_VPS_HOST")
    if not host:
        sys.exit(
            "KONSPEKT_VPS_HOST is not set — see the module docstring for the "
            "environment variables the database commands need."
        )
    return {
        "host": host,
        "user": os.environ.get("KONSPEKT_VPS_USER", "ubuntu"),
        "password": os.environ.get("KONSPEKT_VPS_PASSWORD"),
        "container": os.environ.get("KONSPEKT_DB_CONTAINER", "app-db-1"),
        "pg_user": os.environ.get("KONSPEKT_PG_USER", "saobracaj"),
        "pg_db": os.environ.get("KONSPEKT_PG_DB", "saobracaj_backend"),
    }


def run_sql(sql, psql_flags="-v ON_ERROR_STOP=1"):
    """Run `sql` on the production database and return psql's stdout."""
    cfg = _db_env()
    remote = (
        f"docker exec -i {cfg['container']} "
        f"psql {psql_flags} -U {cfg['pg_user']} -d {cfg['pg_db']}"
    )
    ssh = [
        "ssh",
        "-o", "StrictHostKeyChecking=no",
        "-o", "LogLevel=ERROR",
        f"{cfg['user']}@{cfg['host']}",
        remote,
    ]
    env = dict(os.environ)
    askpass = None
    if cfg["password"]:
        # A throwaway helper that just prints the password; SSH_ASKPASS_REQUIRE
        # =force makes ssh use it even with no tty, so stdin stays ours.
        fd, askpass = tempfile.mkstemp(prefix="explanations-askpass-")
        with os.fdopen(fd, "w") as f:
            f.write('#!/bin/sh\nprintf "%s\\n" "$EXPLANATIONS_SSH_PASSWORD"\n')
        os.chmod(askpass, stat.S_IRWXU)
        env["SSH_ASKPASS"] = askpass
        env["SSH_ASKPASS_REQUIRE"] = "force"
        env["EXPLANATIONS_SSH_PASSWORD"] = cfg["password"]
        env.pop("DISPLAY", None)
    try:
        done = subprocess.run(
            ssh, input=sql, env=env, text=True, capture_output=True, check=False
        )
    finally:
        if askpass:
            os.unlink(askpass)
    if done.returncode != 0:
        sys.stderr.write(done.stdout)
        sys.stderr.write(done.stderr)
        sys.exit(f"database command failed (exit {done.returncode})")
    if done.stderr.strip():
        sys.stderr.write(done.stderr)
    return done.stdout


def _dollar_quote(text):
    """Quote a JSON document for SQL without escaping anything inside it."""
    tag = "expl"
    while f"${tag}$" in text:
        tag += "x"
    return f"${tag}${text}${tag}$"


def cmd_publish(args):
    files = _category_files(args.category_id, args.lang)
    if args.qid:
        files = [p for p in files if int(p.name.split(".")[0]) == args.qid]
    if not files:
        sys.exit(f"nothing to publish for category {args.category_id} ({args.lang})")

    # Publishing unvalidated content is never useful — reuse the exact same
    # checks, on the whole category so cross-file problems surface too.
    cmd_validate(argparse.Namespace(target=args.category_id, lang=args.lang))

    docs = [json.loads(p.read_text(encoding="utf-8")) for p in files]
    total = sum(len(json.dumps(d, ensure_ascii=False)) for d in docs)
    if args.dry_run:
        print(
            f"dry run: would publish {len(docs)} {args.lang} explanation(s) of "
            f"category {args.category_id} ({total} bytes)"
        )
        return

    statements = [TABLE_DDL]
    for doc in docs:
        payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":"))
        statements.append(
            "INSERT INTO saobracaj_question_explanations (question_id, lang, version, document)\n"
            f"VALUES ({int(doc['questionId'])}, '{args.lang}', {int(doc['version'])}, "
            + _dollar_quote(payload)
            + "::jsonb)\n"
            "ON CONFLICT (question_id, lang) DO UPDATE SET\n"
            "    version = EXCLUDED.version,\n"
            "    document = EXCLUDED.document,\n"
            "    updated_by = NULL,\n"
            "    updated_at = now();\n"
        )
    statements.append(
        "SELECT lang, count(*) FROM saobracaj_question_explanations GROUP BY lang;"
    )
    print(run_sql("".join(statements)).strip())
    print(f"published {len(docs)} {args.lang} explanation(s) of category {args.category_id}")


def cmd_published(args):
    if not args.category:
        print(
            run_sql(
                "SELECT lang, count(*), max(updated_at) FROM "
                "saobracaj_question_explanations GROUP BY lang ORDER BY lang;"
            ).strip()
        )
        return
    cat_qids = sorted(q["qId"] for q in category_questions(args.category))
    ids = ",".join(str(i) for i in cat_qids)
    raw = run_sql(
        "SELECT question_id FROM saobracaj_question_explanations "
        f"WHERE lang = '{args.lang}' AND question_id IN ({ids}) ORDER BY question_id;",
        psql_flags="-v ON_ERROR_STOP=1 -tAq",
    )
    stored = {int(line) for line in raw.split() if line.strip()}
    missing = [i for i in cat_qids if i not in stored]
    print(f"category {args.category}: {len(stored)}/{len(cat_qids)} {args.lang} explanations published")
    if missing:
        print(f"missing: {missing}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("queue", help="question ids of a category lacking a local explanation")
    p.add_argument("category_id")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.set_defaults(func=cmd_queue)

    p = sub.add_parser("context", help="question + mapped konspekt blocks, ready to author from")
    p.add_argument("ids", nargs="+")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.set_defaults(func=cmd_context)

    p = sub.add_parser("search-law", help="keyword search over parsed_zakon.json")
    p.add_argument("keywords", nargs="*")
    p.add_argument("--chlan", type=int, help="dump all paragraphs of this article instead")
    p.add_argument("--limit", type=int, default=8)
    p.set_defaults(func=cmd_search_law)

    p = sub.add_parser("validate", help="validate one file or a whole category")
    p.add_argument("target", help="a JSON file path, or a category id")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.set_defaults(func=cmd_validate)

    p = sub.add_parser("publish", help="upload a category's explanations to the database")
    p.add_argument("category_id")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.add_argument("--qid", type=int, help="publish just this one question")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_publish)

    p = sub.add_parser("published", help="what the database currently serves")
    p.add_argument("--category")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.set_defaults(func=cmd_published)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
