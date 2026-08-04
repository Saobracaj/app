#!/usr/bin/env python3
"""CLI helper for generating, validating and publishing category konspekts.

Stdlib-only. Reads bundled app assets; writes nothing except what you ask for.

Konspekts are **stored in the backend database** (table `saobracaj_konspekts`)
and served to the app over GraphQL — they are no longer bundled as Flutter
assets. The authored JSON is kept in the repo under `konspekt_content/` as the
editable source, and `publish` uploads it to the database.

Subcommands:
  categories                       list categories with question counts
  questions CATEGORY_ID            compact dump of all questions in a category
      [--subcategory N] [--images-only]
  validate FILE                    validate a konspekt JSON: structure, question
                                   refs, coverage, illustration refs, dictionary
  publish CATEGORY_ID              validate, then upsert the konspekt into the
      [--file PATH] [--dry-run]    backend database over SSH
  pull CATEGORY_ID [--file PATH]   write the database copy back to a local file
  published                        list what the database currently serves

Database access (publish/pull/published) goes through SSH to the VPS and `psql`
inside the Postgres container. Credentials come from the environment — nothing
is hard-coded, the repo holds no secrets:

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
# Authored konspekt sources. Not a Flutter asset directory: the app downloads
# konspekts from the backend, these files are the editable originals.
CONTENT_DIR = APP_DIR / "konspekt_content"


def load_json(name):
    with open(ASSETS / name, encoding="utf-8") as f:
        return json.load(f)


def load_questions():
    return load_json("allQuestions.json")


def load_ru_hints():
    return {q["qId"]: q for q in load_json("allQuestions_ru.json")}


def cmd_categories(_args):
    qs = load_questions()
    cats = load_json("categories.json")
    counts = {}
    for q in qs:
        counts.setdefault(q["categoryId"], {}).setdefault(q["subcategoryId"], 0)
        counts[q["categoryId"]][q["subcategoryId"]] += 1
    for c in cats:
        sub_counts = counts.get(c["id"], {})
        total = sum(sub_counts.values())
        print(f"{c['id']}  {c['name']}  ({total} questions)")
        for s in c["subcategories"]:
            n = sub_counts.get(s["Id"], 0)
            if n:
                print(f"    sub {s['Id']} ({n}): {s['Description'].strip()}")


def cmd_questions(args):
    qs = [q for q in load_questions() if q["categoryId"] == args.category_id]
    if args.subcategory:
        qs = [q for q in qs if q["subcategoryId"] == args.subcategory]
    if args.images_only:
        qs = [q for q in qs if q["HasImage"]]
    ru = load_ru_hints()
    qs.sort(key=lambda q: (q["subcategoryId"], q["qId"]))
    print(f"# {len(qs)} questions, category {args.category_id}")
    for q in qs:
        img = " IMG" if q["HasImage"] else ""
        multi = f" choose={q['ChoicesReq']}" if q["ChoicesReq"] > 1 else ""
        print(f"\n[{q['qId']}] sub={q['subcategoryId']}{img}{multi}")
        print(f"  SR: {q['Text']}")
        hint = ru.get(q["qId"])
        if hint:
            print(f"  RU: {hint['Text']}")
        for ch in q["Choices"]:
            mark = "✓" if ch["isCorrect"] else "·"
            print(f"   {mark} {ch['Text']}")


SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def _check_localized(errors, path, obj, require_ru=True):
    if not isinstance(obj, dict):
        errors.append(f"{path}: must be an object like {{'ru': ..., 'sr': ...}}")
        return
    if require_ru and not (isinstance(obj.get("ru"), str) and obj["ru"].strip()):
        errors.append(f"{path}.ru: required non-empty string")
    for k in obj:
        if k not in ("ru", "sr"):
            errors.append(f"{path}.{k}: unknown language key (only ru/sr)")


def cmd_validate(args):
    with open(args.file, encoding="utf-8") as f:
        k = json.load(f)
    errors, warnings = [], []

    cat_id = k.get("categoryId")
    if not isinstance(cat_id, str):
        errors.append("categoryId: required string")
    all_qs = load_questions()
    cat_qids = {q["qId"] for q in all_qs if q["categoryId"] == cat_id}
    if cat_id and not cat_qids:
        errors.append(f"categoryId: no questions found for category {cat_id!r}")

    if k.get("version") != 1:
        warnings.append("version: expected 1")
    _check_localized(errors, "categoryName", k.get("categoryName"))
    if "intro" in k:
        _check_localized(errors, "intro", k["intro"])

    sections = k.get("sections")
    if not isinstance(sections, list) or not sections:
        errors.append("sections: required non-empty array")
        sections = []

    seen_ids, referenced_qids = set(), set()
    q_link_re = re.compile(r"\(question\?id=(\d+)\)")
    sect_link_re = re.compile(r"\(konspekt\?category=([^&)]+)&section=([a-z0-9-]+)\)")
    illu_re = re.compile(r"!\[[^\]]*\]\(illustration:([a-z0-9-]+)\)")

    for i, s in enumerate(sections):
        p = f"sections[{i}]"
        sid = s.get("id")
        if not (isinstance(sid, str) and SLUG_RE.match(sid)):
            errors.append(f"{p}.id: required kebab-case slug")
        elif sid in seen_ids:
            errors.append(f"{p}.id: duplicate id {sid!r}")
        else:
            seen_ids.add(sid)
        _check_localized(errors, f"{p}.title", s.get("title"))
        _check_localized(errors, f"{p}.content", s.get("content"))

        illus = s.get("illustrations", [])
        illu_ids = set()
        for j, il in enumerate(illus):
            ip = f"{p}.illustrations[{j}]"
            iid = il.get("id")
            if not (isinstance(iid, str) and SLUG_RE.match(iid)):
                errors.append(f"{ip}.id: required kebab-case slug")
            else:
                illu_ids.add(iid)
            if il.get("type") not in ("image", "animation"):
                errors.append(f"{ip}.type: must be 'image' or 'animation'")
            _check_localized(errors, f"{ip}.description", il.get("description"))

        qids = s.get("questionIds")
        if not isinstance(qids, list) or not all(isinstance(x, int) for x in (qids or [])):
            errors.append(f"{p}.questionIds: required array of ints")
            qids = []
        for qid in qids:
            if qid not in cat_qids:
                errors.append(f"{p}.questionIds: {qid} is not a question of category {cat_id}")
        referenced_qids.update(qids)

        content_ru = (s.get("content") or {}).get("ru") or ""
        for m in q_link_re.finditer(content_ru):
            qid = int(m.group(1))
            if qid not in cat_qids:
                errors.append(f"{p}.content.ru: link to question {qid} outside category")
            elif qid not in qids:
                warnings.append(f"{p}: inline link to {qid} but it is missing from questionIds")
        for m in sect_link_re.finditer(content_ru):
            if m.group(1) != cat_id:
                warnings.append(f"{p}.content.ru: cross-category section link {m.group(0)}")
        for m in illu_re.finditer(content_ru):
            if m.group(1) not in illu_ids:
                errors.append(f"{p}.content.ru: illustration marker {m.group(1)!r} has no matching illustrations[] entry")

    # cross-section links resolve
    for i, s in enumerate(sections):
        content_ru = (s.get("content") or {}).get("ru") or ""
        for m in sect_link_re.finditer(content_ru):
            if m.group(1) == cat_id and m.group(2) not in seen_ids:
                errors.append(f"sections[{i}].content.ru: section link to unknown id {m.group(2)!r}")

    d = k.get("dictionary")
    if not isinstance(d, dict):
        errors.append("dictionary: required object")
    else:
        _check_localized(errors, "dictionary.title", d.get("title"))
        _check_localized(errors, "dictionary.content", d.get("content"))

    missing = sorted(cat_qids - referenced_qids)
    if missing:
        errors.append(
            f"coverage: {len(missing)} of {len(cat_qids)} category questions are not "
            f"covered by any section's questionIds: {missing}"
        )
    else:
        print(f"coverage: all {len(cat_qids)} questions covered by {len(sections)} sections")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        sys.exit(1)
    print("OK")


# ---------------------------------------------------------------- database ---
#
# The backend is the source of truth for konspekt content. There is no direct
# Postgres port on the VPS, so every statement is piped through
# `ssh <vps> docker exec -i <container> psql`. Password auth (when the operator
# supplies one) goes through SSH_ASKPASS rather than a tty helper, which keeps
# stdin free for the SQL we pipe in.

TABLE_DDL = """
CREATE TABLE IF NOT EXISTS saobracaj_konspekts (
    category_id TEXT PRIMARY KEY,
    version     INTEGER NOT NULL DEFAULT 1,
    document    JSONB NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by  UUID
);
"""


def default_source(category_id):
    return CONTENT_DIR / f"{category_id}.json"


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
        fd, askpass = tempfile.mkstemp(prefix="konspekt-askpass-")
        with os.fdopen(fd, "w") as f:
            f.write('#!/bin/sh\nprintf "%s\\n" "$KONSPEKT_SSH_PASSWORD"\n')
        os.chmod(askpass, stat.S_IRWXU)
        env["SSH_ASKPASS"] = askpass
        env["SSH_ASKPASS_REQUIRE"] = "force"
        env["KONSPEKT_SSH_PASSWORD"] = cfg["password"]
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
    tag = "konspekt"
    while f"${tag}$" in text:
        tag += "x"
    return f"${tag}${text}${tag}$"


def cmd_publish(args):
    path = Path(args.file) if args.file else default_source(args.category_id)
    if not path.exists():
        sys.exit(f"{path} does not exist — write the konspekt there first")
    cmd_validate(argparse.Namespace(file=str(path)))

    doc = json.loads(path.read_text(encoding="utf-8"))
    if doc.get("categoryId") != args.category_id:
        sys.exit(
            f"{path} has categoryId {doc.get('categoryId')!r}, "
            f"refusing to publish it as {args.category_id!r}"
        )
    version = doc.get("version", 1)
    payload = json.dumps(doc, ensure_ascii=False, separators=(",", ":"))

    if args.dry_run:
        print(
            f"dry run: would publish category {args.category_id} "
            f"v{version} ({len(payload)} bytes)"
        )
        return

    sql = (
        TABLE_DDL
        + "INSERT INTO saobracaj_konspekts (category_id, version, document)\n"
        + f"VALUES ('{args.category_id}', {int(version)}, "
        + _dollar_quote(payload)
        + "::jsonb)\n"
        + "ON CONFLICT (category_id) DO UPDATE SET\n"
        + "    version = EXCLUDED.version,\n"
        + "    document = EXCLUDED.document,\n"
        + "    updated_by = NULL,\n"
        + "    updated_at = now();\n"
        + "SELECT category_id, version, updated_at,\n"
        + "       jsonb_array_length(document->'sections') AS sections\n"
        + "  FROM saobracaj_konspekts WHERE category_id = "
        + f"'{args.category_id}';\n"
    )
    print(run_sql(sql).strip())
    print(f"published category {args.category_id} v{version} from {path}")


def cmd_pull(args):
    path = Path(args.file) if args.file else default_source(args.category_id)
    raw = run_sql(
        "SELECT document::text FROM saobracaj_konspekts "
        f"WHERE category_id = '{args.category_id}';",
        psql_flags="-v ON_ERROR_STOP=1 -tAq",
    ).strip()
    if not raw:
        sys.exit(f"no konspekt stored for category {args.category_id}")
    doc = json.loads(raw)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"wrote {path} (v{doc.get('version', 1)}, {len(doc.get('sections', []))} sections)")


def cmd_published(_args):
    print(
        run_sql(
            "SELECT category_id, version, updated_at, "
            "jsonb_array_length(document->'sections') AS sections "
            "FROM saobracaj_konspekts ORDER BY category_id;"
        ).strip()
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("categories").set_defaults(func=cmd_categories)

    p = sub.add_parser("questions")
    p.add_argument("category_id")
    p.add_argument("--subcategory", type=int)
    p.add_argument("--images-only", action="store_true")
    p.set_defaults(func=cmd_questions)

    p = sub.add_parser("validate")
    p.add_argument("file")
    p.set_defaults(func=cmd_validate)

    p = sub.add_parser("publish", help="upload a konspekt to the backend database")
    p.add_argument("category_id")
    p.add_argument("--file", help="source JSON (default: konspekt_content/<id>.json)")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_publish)

    p = sub.add_parser("pull", help="write the database copy to a local file")
    p.add_argument("category_id")
    p.add_argument("--file", help="target JSON (default: konspekt_content/<id>.json)")
    p.set_defaults(func=cmd_pull)

    sub.add_parser("published", help="list konspekts stored in the database").set_defaults(
        func=cmd_published
    )

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
