#!/usr/bin/env python3
"""CLI helper for generating and validating category konspekts (study notes).

Stdlib-only. Reads bundled app assets; writes nothing except what you ask for.

Subcommands:
  categories                       list categories with question counts
  questions CATEGORY_ID            compact dump of all questions in a category
      [--subcategory N] [--images-only]
  validate FILE                    validate a konspekt JSON: structure, question
                                   refs, coverage, illustration refs, dictionary
"""
import argparse
import json
import re
import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parents[4]
ASSETS = APP_DIR / "assets"


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

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
