#!/usr/bin/env python3
"""CLI helper for generating, validating and publishing question explanations.

Stdlib-only. Reads bundled app assets; writes nothing except what you ask for.

Explanations are the pre-generated content of the premium "Ask AI" feature:
one JSON document per (question, language), stored in the backend database
(table `saobracaj_question_explanations`) and served over GraphQL
(`questionExplanation` / `questionExplanations`). The authored files are kept
in the repo under `explanation_content/` as the editable source — one file per
category and language — and `publish` uploads them to the database.

Subcommands:
  categories                        list categories with question counts
  context CATEGORY_ID               per-question authoring context: question,
      [--qid N ...] [--subcategory N]   choices (sr+ru), konspekt blocks
  zakon-search QUERY [--limit N]    search the law text (sr and ru)
  zakon CHLAN                       dump one law article with paragraph numbers
  merge CATEGORY_ID FILE...         merge generated fragment files into the
                                    category's explanation_content file
  validate CATEGORY_ID              validate structure, choice refs, link
      [--file PATH] [--allow-partial]   targets and coverage
  publish CATEGORY_ID               validate, then upsert every explanation of
      [--file PATH] [--dry-run]     the category into the backend database
      [--postgres URL] [--allow-partial]
  published                         what the database currently serves

Database access goes through SSH to the VPS and `psql` inside the Postgres
container (same environment variables as the konspekt CLI — nothing is
hard-coded, the repo holds no secrets), or through a local `psql` when
`--postgres URL` is given:

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
from urllib.parse import parse_qs

APP_DIR = Path(__file__).resolve().parents[4]
ASSETS = APP_DIR / "assets"
# Authored explanation sources. Not a Flutter asset directory: the app
# downloads explanations from the backend, these files are the editable
# originals kept in git.
CONTENT_DIR = APP_DIR / "explanation_content"
KONSPEKT_DIR = APP_DIR / "konspekt_content"

LANGS = ("ru", "sr")
SUMMARY_MAX = 300
EXPLANATION_MIN, EXPLANATION_MAX = 150, 2500
WHY_MAX = 500


def load_json(name):
    with open(ASSETS / name, encoding="utf-8") as f:
        return json.load(f)


def load_questions():
    return load_json("allQuestions.json")


def load_ru_hints():
    return {q["qId"]: q for q in load_json("allQuestions_ru.json")}


def load_zakon():
    return load_json("parsed_zakon.json")


def content_path(category_id, lang):
    suffix = "" if lang == "ru" else f".{lang}"
    return CONTENT_DIR / f"{category_id}{suffix}.json"


# ------------------------------------------------------------------ context ---


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


def konspekt_blocks_by_question(category_id):
    """qId -> [(section_id, block_content_ru)] from the category's konspekt."""
    path = KONSPEKT_DIR / f"{category_id}.json"
    if not path.exists():
        return {}
    k = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for s in k.get("sections", []):
        for b in s.get("blocks") or []:
            text = (b.get("content") or {}).get("ru") or ""
            for qid in b.get("questionIds", []):
                out.setdefault(qid, []).append((s["id"], text))
    return out


def cmd_context(args):
    qs = [q for q in load_questions() if q["categoryId"] == args.category_id]
    if args.subcategory:
        qs = [q for q in qs if q["subcategoryId"] == args.subcategory]
    if args.qid:
        wanted = set(args.qid)
        qs = [q for q in qs if q["qId"] in wanted]
        missing = wanted - {q["qId"]} if not qs else wanted - {q["qId"] for q in qs}
        if missing:
            sys.exit(f"not in category {args.category_id}: {sorted(missing)}")
    ru = load_ru_hints()
    blocks = konspekt_blocks_by_question(args.category_id)
    qs.sort(key=lambda q: (q["subcategoryId"], q["qId"]))
    print(f"# {len(qs)} questions, category {args.category_id}")
    for q in qs:
        img = " IMG(assets/img/%d.jpeg)" % q["qId"] if q["HasImage"] else ""
        multi = f" choose={q['ChoicesReq']}" if q["ChoicesReq"] > 1 else ""
        print(f"\n[{q['qId']}] sub={q['subcategoryId']}{img}{multi}")
        print(f"  SR: {q['Text']}")
        hint = ru.get(q["qId"])
        if hint:
            print(f"  RU: {hint['Text']}")
        ru_choices = (hint or {}).get("Choices", [])
        for idx, ch in enumerate(q["Choices"]):
            mark = "✓" if ch["isCorrect"] else "·"
            print(f"   {mark} [{idx}] {ch['Text']}")
            if idx < len(ru_choices):
                print(f"         RU: {ru_choices[idx]['Text']}")
        if q.get("zakon"):
            print(f"  ZAKON: {q['zakon']}")
        for section_id, text in blocks.get(q["qId"], []):
            one_line = " ".join(text.split())
            print(f"  KONSPEKT[{section_id}]: {one_line}")


def cmd_zakon_search(args):
    needle = args.query.lower()
    hits = 0
    for f in load_zakon():
        if not f.get("chlan"):
            continue
        sr, ru = f.get("sr") or "", f.get("ru") or ""
        if needle in sr.lower() or needle in ru.lower():
            hits += 1
            print(f"chapter={f['chapter']} chlan={f['chlan']} ¶{f['paragraph']}")
            print(f"  SR: {sr[:200]}")
            print(f"  RU: {ru[:200]}")
            if hits >= args.limit:
                print(f"... (limit {args.limit} reached, refine the query)")
                break
    if not hits:
        print("no matches")


def cmd_zakon(args):
    frags = [f for f in load_zakon() if str(f.get("chlan")) == str(args.chlan)]
    if not frags:
        sys.exit(f"no fragments for chlan {args.chlan}")
    print(f"# члан {args.chlan}, chapter {frags[0]['chapter']}, {len(frags)} fragments")
    for f in frags:
        print(f"\n¶{f['paragraph']}")
        print(f"  SR: {f.get('sr') or ''}")
        print(f"  RU: {f.get('ru') or ''}")


# ---------------------------------------------------------------- authoring ---


def load_content(category_id, lang, path=None):
    path = Path(path) if path else content_path(category_id, lang)
    if not path.exists():
        sys.exit(f"{path} does not exist — author the explanations there first")
    return path, json.loads(path.read_text(encoding="utf-8"))


def _squash_ws(text):
    return " ".join(str(text).split())


def _snap_choice_texts(doc, questions):
    """Replace a wrongChoice's text with the asset's verbatim string when the two
    differ only in whitespace — the assets use non-breaking spaces ('200 m') that
    are impossible to reproduce by hand and would fail validation."""
    snapped = 0
    for e in doc.get("explanations", []):
        q = questions.get(e.get("questionId"))
        if not q:
            continue
        choices = q.get("Choices") or []
        for w in e.get("wrongChoices") or []:
            idx = w.get("index")
            if not isinstance(idx, int) or not 0 <= idx < len(choices):
                continue
            verbatim = choices[idx].get("Text", "")
            if w.get("text") != verbatim and _squash_ws(w.get("text")) == _squash_ws(verbatim):
                w["text"] = verbatim
                snapped += 1
    return snapped


def cmd_merge(args):
    """Merge fragment files (each a JSON array of explanation documents) into
    the category's content file, so generation can be fanned out and collected.
    A fragment document replaces an existing one for the same questionId."""
    path = content_path(args.category_id, args.lang)
    if path.exists():
        doc = json.loads(path.read_text(encoding="utf-8"))
    else:
        doc = {"categoryId": args.category_id, "lang": args.lang, "explanations": []}
    by_id = {e["questionId"]: e for e in doc["explanations"]}
    added = replaced = 0
    for frag_path in args.files:
        frag = json.loads(Path(frag_path).read_text(encoding="utf-8"))
        if not isinstance(frag, list):
            sys.exit(f"{frag_path}: fragment must be a JSON array of documents")
        for e in frag:
            qid = e.get("questionId")
            if not isinstance(qid, int):
                sys.exit(f"{frag_path}: document without integer questionId")
            if qid in by_id:
                replaced += 1
            else:
                added += 1
            by_id[qid] = e
    doc["explanations"] = [by_id[k] for k in sorted(by_id)]
    questions = {q["qId"]: q for q in load_questions() if q["categoryId"] == args.category_id}
    snapped = _snap_choice_texts(doc, questions)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    note = f", {snapped} choice text(s) snapped to the assets" if snapped else ""
    print(f"{path}: {added} added, {replaced} replaced, {len(by_id)} total{note}")


# --------------------------------------------------------------- validation ---

URI_RE = re.compile(r"\]\(([a-z]+\?[^)\s]+)\)")


def _check_uri(uri, ctx, cat_qids, all_qids, zakon_keys, konspekt_sections, errors, warnings):
    """Validate one app URI (zakon?…, konspekt?…, question?…)."""
    kind, _, query = uri.partition("?")
    params = {k: v[0] for k, v in parse_qs(query).items()}
    if kind == "question":
        qid = params.get("id")
        if not (qid and qid.isdigit() and int(qid) in all_qids):
            errors.append(f"{ctx}: link to unknown question {uri!r}")
    elif kind == "zakon":
        chlan = params.get("chlan")
        if not chlan:
            errors.append(f"{ctx}: zakon link without chlan: {uri!r}")
        elif chlan not in zakon_keys:
            errors.append(f"{ctx}: zakon link to unknown члан {chlan!r}")
        else:
            paragraph = params.get("paragraph")
            if paragraph is not None and (chlan, paragraph) not in zakon_keys[chlan]:
                errors.append(f"{ctx}: zakon link to unknown ¶{paragraph} of члан {chlan}")
    elif kind == "konspekt":
        cat = params.get("category")
        section = params.get("section")
        sections = konspekt_sections.get(cat)
        if sections is None:
            errors.append(f"{ctx}: konspekt link to category {cat!r} without a konspekt file")
        elif section not in sections:
            errors.append(f"{ctx}: konspekt link to unknown section {section!r}")
    else:
        warnings.append(f"{ctx}: unrecognized link scheme {uri!r}")


def validate(category_id, lang, path=None, allow_partial=False):
    path, doc = load_content(category_id, lang, path)
    errors, warnings = [], []

    if doc.get("categoryId") != category_id:
        errors.append(f"categoryId: file says {doc.get('categoryId')!r}, expected {category_id!r}")
    if doc.get("lang") != lang:
        errors.append(f"lang: file says {doc.get('lang')!r}, expected {lang!r}")

    all_qs = load_questions()
    questions = {q["qId"]: q for q in all_qs if q["categoryId"] == category_id}
    all_qids = {q["qId"] for q in all_qs}
    if not questions:
        errors.append(f"no questions found for category {category_id!r}")

    zakon_keys = {}
    for f in load_zakon():
        if f.get("chlan"):
            zakon_keys.setdefault(str(f["chlan"]), set()).add(
                (str(f["chlan"]), str(f["paragraph"]))
            )
    konspekt_sections = {}
    for k_path in KONSPEKT_DIR.glob("*.json"):
        k = json.loads(k_path.read_text(encoding="utf-8"))
        konspekt_sections[k.get("categoryId")] = {
            s.get("id") for s in k.get("sections", [])
        }

    explanations = doc.get("explanations")
    if not isinstance(explanations, list) or not explanations:
        errors.append("explanations: required non-empty array")
        explanations = []

    seen = set()
    for i, e in enumerate(explanations):
        qid = e.get("questionId")
        p = f"explanations[{i}] (qId {qid})"
        if not isinstance(qid, int):
            errors.append(f"{p}: questionId must be an int")
            continue
        if qid in seen:
            errors.append(f"{p}: duplicate questionId")
            continue
        seen.add(qid)
        q = questions.get(qid)
        if q is None:
            errors.append(f"{p}: not a question of category {category_id}")
            continue
        if e.get("lang") != lang:
            errors.append(f"{p}: lang must be {lang!r}")
        if not (isinstance(e.get("version"), int) and e["version"] >= 1):
            errors.append(f"{p}: version must be a positive int")

        summary = e.get("summary")
        if not (isinstance(summary, str) and summary.strip()):
            errors.append(f"{p}: summary is a required non-empty string")
        elif len(summary) > SUMMARY_MAX:
            errors.append(f"{p}: summary is {len(summary)} chars (max {SUMMARY_MAX})")

        explanation = e.get("explanation")
        if not (isinstance(explanation, str) and explanation.strip()):
            errors.append(f"{p}: explanation is a required non-empty string")
        else:
            if len(explanation) < EXPLANATION_MIN:
                warnings.append(f"{p}: explanation is only {len(explanation)} chars")
            if len(explanation) > EXPLANATION_MAX:
                errors.append(
                    f"{p}: explanation is {len(explanation)} chars (max {EXPLANATION_MAX})"
                )

        incorrect = {
            idx for idx, ch in enumerate(q["Choices"]) if not ch["isCorrect"]
        }
        wrong = e.get("wrongChoices")
        if not isinstance(wrong, list):
            errors.append(f"{p}: wrongChoices must be an array (may be empty)")
            wrong = []
        covered = set()
        for j, w in enumerate(wrong):
            wp = f"{p}.wrongChoices[{j}]"
            idx = w.get("index")
            if not (isinstance(idx, int) and 0 <= idx < len(q["Choices"])):
                errors.append(f"{wp}: index out of range")
                continue
            if idx not in incorrect:
                errors.append(f"{wp}: choice {idx} is a CORRECT choice")
            if w.get("text") != q["Choices"][idx]["Text"]:
                errors.append(
                    f"{wp}: text does not match the choice — expected "
                    f"{q['Choices'][idx]['Text']!r}"
                )
            why = w.get("why")
            if not (isinstance(why, str) and why.strip()):
                errors.append(f"{wp}: why is a required non-empty string")
            elif len(why) > WHY_MAX:
                errors.append(f"{wp}: why is {len(why)} chars (max {WHY_MAX})")
            covered.add(idx)
        if len(q["Choices"]) > 2 and incorrect and not wrong:
            errors.append(
                f"{p}: {len(incorrect)} incorrect choices and no wrongChoices — "
                f"multi-option questions must explain the distractors"
            )
        elif incorrect - covered and wrong:
            warnings.append(
                f"{p}: incorrect choices not covered by wrongChoices: "
                f"{sorted(incorrect - covered)}"
            )

        sources = e.get("sources")
        if not (isinstance(sources, list) and sources):
            errors.append(f"{p}: sources is a required non-empty array")
            sources = []
        has_zakon = False
        for j, s in enumerate(sources):
            sp = f"{p}.sources[{j}]"
            if s.get("type") not in ("zakon", "konspekt", "question"):
                errors.append(f"{sp}: type must be zakon|konspekt|question")
            has_zakon = has_zakon or s.get("type") == "zakon"
            if not (isinstance(s.get("title"), str) and s["title"].strip()):
                errors.append(f"{sp}: title is a required non-empty string")
            uri = s.get("uri")
            if not (isinstance(uri, str) and "?" in uri):
                errors.append(f"{sp}: uri is a required app link")
            else:
                _check_uri(
                    uri, sp, set(questions), all_qids, zakon_keys,
                    konspekt_sections, errors, warnings,
                )
        if sources and not has_zakon:
            warnings.append(f"{p}: no zakon source — most questions should cite the law")

        # Inline markdown links inside the running text follow the same rules.
        texts = [(f"{p}.explanation", explanation or "")]
        texts += [
            (f"{p}.wrongChoices[{j}].why", w.get("why") or "")
            for j, w in enumerate(wrong)
        ]
        for ctx, text in texts:
            for m in URI_RE.finditer(text):
                _check_uri(
                    m.group(1), ctx, set(questions), all_qids, zakon_keys,
                    konspekt_sections, errors, warnings,
                )

    missing = sorted(set(questions) - seen)
    if missing:
        line = (
            f"coverage: {len(missing)} of {len(questions)} category questions "
            f"have no explanation: {missing}"
        )
        (warnings if allow_partial else errors).append(line)
    else:
        print(f"coverage: all {len(questions)} questions of category {category_id} covered")

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    if errors:
        sys.exit(1)
    print("OK")
    return path, doc


def cmd_validate(args):
    validate(args.category_id, args.lang, args.file, args.allow_partial)


# ---------------------------------------------------------------- database ---
#
# Same machinery as the konspekt CLI: no direct Postgres port on the VPS, so
# SQL is piped through `ssh <vps> docker exec -i <container> psql`; password
# auth goes through SSH_ASKPASS to keep stdin free for the SQL itself.
# `--postgres URL` switches to a local psql for testing.

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
            "KONSPEKT_VPS_HOST is not set (and no --postgres URL given) — see "
            "the module docstring for the environment variables needed."
        )
    return {
        "host": host,
        "user": os.environ.get("KONSPEKT_VPS_USER", "ubuntu"),
        "password": os.environ.get("KONSPEKT_VPS_PASSWORD"),
        "container": os.environ.get("KONSPEKT_DB_CONTAINER", "app-db-1"),
        "pg_user": os.environ.get("KONSPEKT_PG_USER", "saobracaj"),
        "pg_db": os.environ.get("KONSPEKT_PG_DB", "saobracaj_backend"),
    }


def run_sql(sql, postgres_url=None, psql_flags="-v ON_ERROR_STOP=1"):
    if postgres_url:
        done = subprocess.run(
            ["psql"] + psql_flags.split() + [postgres_url],
            input=sql, text=True, capture_output=True, check=False,
        )
        return _report(done)
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
    return _report(done)


def _report(done):
    if done.returncode != 0:
        sys.stderr.write(done.stdout)
        sys.stderr.write(done.stderr)
        sys.exit(f"database command failed (exit {done.returncode})")
    if done.stderr.strip():
        sys.stderr.write(done.stderr)
    return done.stdout


def _dollar_quote(text):
    tag = "expl"
    while f"${tag}$" in text:
        tag += "x"
    return f"${tag}${text}${tag}$"


def cmd_publish(args):
    path, doc = validate(args.category_id, args.lang, args.file, args.allow_partial)
    explanations = doc["explanations"]

    values = []
    for e in explanations:
        payload = json.dumps(e, ensure_ascii=False, separators=(",", ":"))
        values.append(
            f"({e['questionId']}, '{args.lang}', {int(e['version'])}, "
            f"{_dollar_quote(payload)}::jsonb, NULL)"
        )
    qids_sql = ",".join(str(e["questionId"]) for e in explanations)
    sql = (
        TABLE_DDL
        + "INSERT INTO saobracaj_question_explanations "
        + "(question_id, lang, version, document, updated_by)\nVALUES\n"
        + ",\n".join(values)
        + "\nON CONFLICT (question_id, lang) DO UPDATE SET\n"
        + "    version = EXCLUDED.version,\n"
        + "    document = EXCLUDED.document,\n"
        + "    updated_by = NULL,\n"
        + "    updated_at = now();\n"
        + "SELECT lang, count(*) AS stored, max(updated_at) AS last_update\n"
        + "  FROM saobracaj_question_explanations\n"
        + f" WHERE question_id IN ({qids_sql})\n"
        + " GROUP BY lang ORDER BY lang;\n"
    )
    if args.dry_run:
        print(
            f"dry run: would publish {len(explanations)} explanations of "
            f"category {args.category_id} ({args.lang}, {len(sql)} bytes of SQL)"
        )
        return
    print(run_sql(sql, args.postgres).strip())
    print(
        f"published {len(explanations)} explanations of category "
        f"{args.category_id} ({args.lang}) from {path}"
    )


def cmd_published(args):
    print(
        run_sql(
            "SELECT lang, count(*) AS explanations, max(updated_at) AS last_update "
            "FROM saobracaj_question_explanations GROUP BY lang ORDER BY lang;",
            args.postgres,
        ).strip()
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("categories").set_defaults(func=cmd_categories)

    p = sub.add_parser("context", help="authoring context for a category's questions")
    p.add_argument("category_id")
    p.add_argument("--qid", type=int, action="append", help="only these questions")
    p.add_argument("--subcategory", type=int)
    p.set_defaults(func=cmd_context)

    p = sub.add_parser("zakon-search", help="search the law text")
    p.add_argument("query")
    p.add_argument("--limit", type=int, default=20)
    p.set_defaults(func=cmd_zakon_search)

    p = sub.add_parser("zakon", help="dump one law article")
    p.add_argument("chlan")
    p.set_defaults(func=cmd_zakon)

    p = sub.add_parser("merge", help="merge fragment files into the content file")
    p.add_argument("category_id")
    p.add_argument("files", nargs="+")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.set_defaults(func=cmd_merge)

    p = sub.add_parser("validate")
    p.add_argument("category_id")
    p.add_argument("--file", help="source JSON (default: explanation_content/<id>.json)")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.add_argument("--allow-partial", action="store_true",
                   help="missing questions are a warning, not an error")
    p.set_defaults(func=cmd_validate)

    p = sub.add_parser("publish", help="upload a category's explanations to the database")
    p.add_argument("category_id")
    p.add_argument("--file", help="source JSON (default: explanation_content/<id>.json)")
    p.add_argument("--lang", default="ru", choices=LANGS)
    p.add_argument("--allow-partial", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--postgres", metavar="URL",
                   help="run against this database via a local psql instead of SSH")
    p.set_defaults(func=cmd_publish)

    p = sub.add_parser("published", help="what the database currently serves")
    p.add_argument("--postgres", metavar="URL")
    p.set_defaults(func=cmd_published)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
