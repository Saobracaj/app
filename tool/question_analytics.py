#!/usr/bin/env python3
"""Build `assets/question_analytics.json` — the static analytics shown on a
question's "Анализа" tab.

Everything here is derived from the two bundled assets and nothing else:

* `assets/practice.json` — 699 real exam variants (the official sample), each a
  list of 41 question ids;
* `assets/allQuestions.json` — the 1701-question catalogue (points, category,
  subcategory, answer options with their correctness).

Three families of numbers come out of it:

1. **How the exam is assembled.** Reverse-engineered from the sample and then
   verified against it (see `_pools` and `--verify`), so the probability of a
   question showing up is a model number, not a raw frequency: the sample is far
   too small to estimate 1557 individual probabilities (144 questions never
   occur in it at all).
2. **What a question is worth** — expected points per exam, `p * Points`.
3. **Keyword analysis** — cues a learner can memorise an answer by: answer
   options (whole, or a phrase inside them) that are correct — or wrong — in
   every question of the bank where they occur, and links "phrase in the
   question → the correct answer" that hold across the bank. Computed on the
   Serbian text only: that is the language the exam is written in, and the
   Russian translations (`allQuestions_ru.json`) exist purely to help a
   learner read the Serbian, so cues found in them would be cues to nothing.

Usage:
    python3 tool/question_analytics.py            # writes the asset
    python3 tool/question_analytics.py --verify   # + prints the model checks
"""

from __future__ import annotations

import argparse
import collections
import json
import math
import re
import statistics
import sys
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / "assets"
OUTPUT = ASSETS / "question_analytics.json"

SCHEMA_VERSION = 3

# ---------------------------------------------------------------------------
# Exam model
# ---------------------------------------------------------------------------

# A keyword cue is reported only when it is *absolute* — every option in the
# bank carrying it is correct (or every one is wrong) — and that record is
# unlikely under the base rate. Only about 36% of options are correct, so four
# correct ones in a row is a 1.6% coincidence while four wrong ones is a 17%
# one; the p-value threshold, not a fixed count, therefore decides how many
# occurrences a cue needs (4 for "always correct", 9 for "always wrong").
MARKER_MAX_P_VALUE = 0.02
# Longest phrase considered, in words. Whole option texts are always
# considered as well, however long.
MAX_MARKER_WORDS = 4
# Longest phrase of the question stem used on the left-hand side of a link.
MAX_STEM_WORDS = 3
# A stem phrase found in more than this share of all questions ("возач",
# "слици") conditions on nothing and is not offered as a link cue.
MAX_LINK_STEM_SHARE = 0.15
# A link must hold in at least this many distinct questions.
MIN_LINK_QUESTIONS = 4


def load(name: str):
    with open(ASSETS / name, encoding="utf-8") as fh:
        return json.load(fh)


def _pools(questions, exams):
    """Reverse-engineer the exam's blueprint from the sample.

    Every one of the 699 sampled exams holds exactly 41 questions with an
    identical *category* profile (1×25, 1×26, 1×28, 2×29, 18×30, 13×32, 1×33,
    2×34, 1×35, 1×36). One level down, most subcategories also contribute a
    constant number of questions to every exam — those are their own pool. The
    subcategories that vary within a category always vary *together*, summing to
    a constant: they share one slot, i.e. they form a single pool.

    Returns `{pool_id: {"subcategories": [...], "slots": k, "size": n}}`, where a
    pool's questions are drawn uniformly without replacement, so any one of them
    is on a given exam with probability `k / n`. `--verify` checks that
    uniformity with a chi-square test rather than assuming it.
    """
    by_sub = collections.defaultdict(list)
    for q in questions:
        by_sub[q["subcategoryId"]].append(q["qId"])
    sub_cat = {q["subcategoryId"]: q["categoryId"] for q in questions}

    # How many questions each subcategory contributes, exam by exam.
    per_exam = collections.defaultdict(list)
    q_sub = {q["qId"]: q["subcategoryId"] for q in questions}
    for exam in exams:
        counts = collections.Counter(q_sub[qid] for qid in exam)
        for sub in by_sub:
            per_exam[sub].append(counts.get(sub, 0))

    pools = {}
    shared = collections.defaultdict(list)  # categoryId -> varying subcategories
    for sub, counts in per_exam.items():
        if statistics.pstdev(counts) == 0:
            slots = counts[0]
            pools[f"s{sub}"] = {
                "subcategories": [sub],
                "slots": slots,
                "size": len(by_sub[sub]),
            }
        else:
            shared[sub_cat[sub]].append(sub)

    for category, subs in shared.items():
        total = [sum(per_exam[s][i] for s in subs) for i in range(len(exams))]
        assert statistics.pstdev(total) == 0, (
            f"category {category}: subcategories {sorted(subs)} do not share a "
            f"constant number of slots ({sorted(set(total))})"
        )
        pools[f"c{category}"] = {
            "subcategories": sorted(subs),
            "slots": total[0],
            "size": sum(len(by_sub[s]) for s in subs),
        }

    return pools


def _probabilities(questions, pools):
    """`qId -> (probability of being on one exam, pool id)`."""
    pool_of = {}
    for pool_id, pool in pools.items():
        for sub in pool["subcategories"]:
            pool_of[sub] = pool_id
    out = {}
    for q in questions:
        pool_id = pool_of[q["subcategoryId"]]
        pool = pools[pool_id]
        out[q["qId"]] = (pool["slots"] / pool["size"], pool_id)
    return out


# ---------------------------------------------------------------------------
# Keyword analysis
# ---------------------------------------------------------------------------

_WORD = re.compile(r"[^\w]+", re.UNICODE)
# Phrases are taken within a clause: "…на слици, дужни сте…" must not yield the
# cross-comma fragment "слици дужни".
_CLAUSE = re.compile(r"[,;:.!?()\[\]«»„“”\"/–—-]+")

# Function words carry no exam signal, and letting them into n-grams buries the
# real phrases under "и на путу"-style noise. Serbian only, Cyrillic and Latin:
# the analysis runs on the Serbian catalogue alone.
STOPWORDS = {
    "и", "или", "а", "али", "да", "је", "су", "се", "би", "бити", "сам", "сте",
    "смо", "си", "ће", "ћете", "ћу", "ли", "у", "на", "од", "до", "за", "са",
    "код", "по", "из", "о", "об", "уз", "низ", "пре", "после", "при", "кроз",
    "ка", "к", "те", "тако", "као", "што", "који", "која", "које", "којих",
    "којим", "коју", "којој", "којем", "коме", "ако", "већ", "још", "само", "сваки",
    "свака", "свако", "тај", "та", "то", "тог", "тим", "том", "ово", "овај",
    "ова", "овом", "оних", "они", "оне", "она", "он", "оно", "му", "им", "их",
    "ме", "га", "јој", "њега", "њему", "мора", "може", "себе", "себи", "свој",
    "своје", "своју", "свог", "свом", "ваш", "ваше", "вам", "вас", "јер", "док",
    "када", "кад", "где", "чија", "чије", "чији", "него", "односно",
    "i", "ili", "a", "ali", "da", "je", "su", "se", "u", "na", "od", "do",
    "za", "sa", "po", "iz", "o", "pre", "posle", "pri", "kroz", "kao", "sto",
}

# Negations are the one kind of function word that *is* the signal ("не сме",
# "није дозвољено"), so a phrase may start with one — but not end on one.
NEGATIONS = {"не", "није", "нису", "ни", "ne", "nije"}


def _tokens(text: str):
    return [t for t in _WORD.split(text.lower()) if t]


def _normal(text: str) -> str:
    """The comparable form of a whole option: lower-case, punctuation-free."""
    return " ".join(_tokens(text))


def _ngrams(text: str, max_words: int):
    """Content n-grams of a piece of text, 1..`max_words` words, within clauses.

    An n-gram may not end on a stopword and may start on one only if it is a
    negation (`"у случају"` and `"не сме"` are phrases; `"у"` and `"случају у"`
    are not), which keeps the candidate set to phrases a person would recognise
    as one.
    """
    out = set()
    for clause in _CLAUSE.split(text):
        words = _tokens(clause)
        for n in range(1, max_words + 1):
            for i in range(len(words) - n + 1):
                gram = words[i : i + n]
                if gram[0] in STOPWORDS and gram[0] not in NEGATIONS:
                    continue
                if gram[-1] in STOPWORDS or gram[-1] in NEGATIONS:
                    continue
                if all(len(w) < 3 for w in gram):
                    continue
                out.add(" ".join(gram))
    return out


def _binom_tail(k: int, n: int, p: float) -> float:
    """P(X >= k) for X ~ Binomial(n, p). Exact; n is at most a few thousand."""
    if k <= 0:
        return 1.0
    total = 0.0
    for i in range(k, n + 1):
        total += math.exp(
            math.lgamma(n + 1)
            - math.lgamma(i + 1)
            - math.lgamma(n - i + 1)
            + i * math.log(p)
            + (n - i) * math.log1p(-p)
        )
    return min(1.0, total)


def _phrase_key(phrase: str):
    """Sort key preferring the shortest phrasing: fewer words, then fewer chars."""
    return (len(phrase.split()), len(phrase))


def _markers(catalogue, correctness):
    """Answer-option cues that hold across the whole bank.

    `catalogue` is `qId -> [option text]` (Serbian) and `correctness` is
    `qId -> [bool]`.

    Two kinds of cue are looked for in every option: the option *as a whole*
    ("Униформисани полицијски службеници" is an answer in four questions and is
    correct in all four) and every content phrase of up to `MAX_MARKER_WORDS`
    inside it. A cue is kept when its options are all correct or all wrong and
    that record is unlikely under the base rate (`MARKER_MAX_P_VALUE`); nothing
    "mostly" is reported — a learner memorises a rule, not a tendency.

    Redundant cues collapse onto one: a phrase whose options are all covered by
    a whole-option cue of the same kind is dropped (the whole answer is the
    better thing to remember), and among phrases the shortest one covering the
    same options wins ("потреба" over "постоји потреба").
    """
    options = []  # (qId, choice index, is correct)
    holders = collections.defaultdict(set)  # (phrase, whole?) -> option indices
    for qid, texts in catalogue.items():
        for idx, text in enumerate(texts):
            option = len(options)
            options.append((qid, idx, correctness[qid][idx]))
            whole = _normal(text)
            if whole:
                holders[(whole, True)].add(option)
            for gram in _ngrams(text, MAX_MARKER_WORDS):
                holders[(gram, False)].add(option)

    base = sum(1 for _, _, ok in options if ok) / len(options)

    found = []
    for (phrase, whole), owners in holders.items():
        n = len(owners)
        if n < 2:
            continue
        correct = sum(1 for o in owners if options[o][2])
        if correct == n:
            kind, p_value = "alwaysCorrect", _binom_tail(n, n, base)
        elif correct == 0:
            kind, p_value = "alwaysWrong", _binom_tail(n, n, 1 - base)
        else:
            continue
        if p_value > MARKER_MAX_P_VALUE:
            continue
        found.append(
            {
                "phrase": phrase,
                "kind": kind,
                "whole": whole,
                "options": n,
                "correct": correct,
                "owners": owners,
            }
        )

    # Phrases that decide exactly the same options are one cue. Of those, the
    # whole answer wins; among fragments a two- or three-word phrase is kept
    # over a lone word ("пред сваком препреком", not "датим"), since it is the
    # one a learner will recognise in the text.
    groups = {}
    for marker in found:
        key = (marker["kind"], frozenset(marker["owners"]))
        rank = (
            not marker["whole"],
            -min(len(marker["phrase"].split()), 3),
            -len(marker["phrase"]),
        )
        if key not in groups or rank < groups[key][0]:
            groups[key] = (rank, marker)
    found = [marker for _, marker in groups.values()]

    # Whole-option cues first, then phrases shortest first, so that each cue is
    # compared against the ones that should absorb it.
    found.sort(key=lambda m: (not m["whole"], _phrase_key(m["phrase"])))
    kept = []
    for marker in found:
        if any(
            k["kind"] == marker["kind"]
            and marker["owners"] <= k["owners"]
            and (k["whole"] or k["phrase"] in marker["phrase"])
            for k in kept
        ):
            continue
        kept.append(marker)

    kept.sort(key=lambda m: (-m["options"], not m["whole"], m["phrase"]))
    per_question = collections.defaultdict(list)
    catalog = []
    for index, marker in enumerate(kept):
        catalog.append(
            {
                "phrase": marker["phrase"],
                "kind": marker["kind"],
                "whole": marker["whole"],
                "options": marker["options"],
                "correct": marker["correct"],
            }
        )
        for owner in marker["owners"]:
            qid, choice, _ = options[owner]
            per_question[qid].append({"m": index, "c": choice})
    return catalog, per_question, base


def _content(text: str) -> bool:
    """Whether a phrase has a real word in it — "1" or "5 000" do not."""
    return any(len(t) >= 4 and t.isalpha() for t in _tokens(text))


def _links(catalogue, stems, correctness):
    """"Phrase in the question → the correct answer" rules.

    A link `(S, A)` says: in every question of the bank whose stem contains
    `S` and offers the answer `A`, `A` is the correct one. It is worth reporting
    only when `A` alone does *not* settle the matter — "Новчаном казном од
    5 000 динара" is right in some questions and wrong in others, but in the
    questions about parking ("паркира") it is always right; that is the thing
    to remember. Only whole answers are considered on the right-hand side:
    fragments of them ("без", "лица") pass every statistical test and mean
    nothing to a learner.

    A link is kept when it holds in at least `MIN_LINK_QUESTIONS` distinct
    questions, `A` on its own is impure across the bank, the run of successes is
    unlikely given `A`'s own correct rate (`MARKER_MAX_P_VALUE`), and `S` is
    specific enough (`MAX_LINK_STEM_SHARE`). Links that hold on exactly the
    same set of question-options are one rule, reported with the shortest `S`
    (the broadest condition that still holds).
    """
    answer_record = collections.defaultdict(list)  # A -> [is correct]
    stem_count = collections.Counter()  # S -> questions containing it
    for qid, texts in catalogue.items():
        for idx, text in enumerate(texts):
            answer_record[_normal(text)].append(correctness[qid][idx])
        for gram in _ngrams(stems[qid], MAX_STEM_WORDS):
            stem_count[gram] += 1

    max_stem = MAX_LINK_STEM_SHARE * len(catalogue)
    # An answer that is already an absolute cue needs no condition; one with a
    # single counter-example is too close to it to be worth a rule of its own.
    impure = {
        a
        for a, record in answer_record.items()
        if 0 < sum(record) < len(record)
        and len(record) - sum(record) >= 2
        and _content(a)
    }

    pairs = collections.defaultdict(list)  # (S, A) -> [(qid, idx, ok)]
    for qid, texts in catalogue.items():
        stem_grams = [
            g for g in _ngrams(stems[qid], MAX_STEM_WORDS) if stem_count[g] <= max_stem
        ]
        if not stem_grams:
            continue
        for idx, text in enumerate(texts):
            answer = _normal(text)
            if answer not in impure:
                continue
            ok = correctness[qid][idx]
            for s in stem_grams:
                pairs[(s, answer)].append((qid, idx, ok))

    found = []
    for (s, a), owners in pairs.items():
        if len({qid for qid, _, _ in owners}) < MIN_LINK_QUESTIONS:
            continue
        if not all(ok for _, _, ok in owners):
            continue
        record = answer_record[a]
        rate = sum(record) / len(record)
        if _binom_tail(len(owners), len(owners), rate) > MARKER_MAX_P_VALUE:
            continue
        found.append(
            {
                "stem": s,
                "answer": a,
                "owners": frozenset((qid, idx) for qid, idx, _ in owners),
            }
        )

    # One rule per (answer, owner set): the shortest S.
    best = {}
    for link in found:
        key = (link["answer"], link["owners"])
        if key not in best or _phrase_key(link["stem"]) < _phrase_key(best[key]["stem"]):
            best[key] = link
    # A rule whose owners are a subset of another rule's for the same answer is
    # the same rule under a narrower condition — drop it.
    kept = sorted(best.values(), key=lambda l: -len(l["owners"]))
    final = []
    for link in kept:
        if any(
            f["answer"] == link["answer"] and link["owners"] <= f["owners"]
            for f in final
        ):
            continue
        final.append(link)

    final.sort(key=lambda l: (-len(l["owners"]), l["stem"], l["answer"]))
    per_question = collections.defaultdict(list)
    catalog = []
    for index, link in enumerate(final):
        catalog.append(
            {
                "stem": link["stem"],
                "answer": link["answer"],
                "questions": len({qid for qid, _ in link["owners"]}),
            }
        )
        for qid, idx in link["owners"]:
            per_question[qid].append({"l": index, "c": idx})
    return catalog, per_question


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


def build(verify: bool = False):
    questions = load("allQuestions.json")
    exams = load("practice.json")

    pools = _pools(questions, exams)
    probability = _probabilities(questions, pools)

    seen = collections.Counter()
    for exam in exams:
        seen.update(exam)

    # Expected points a question contributes to a random exam: what you stand to
    # lose by not knowing it. The average over the questions that can appear is
    # the yardstick the three tiers are cut against, so "high" means "worth
    # several average questions" rather than "in the top third of a list".
    values = {}
    for q in questions:
        p, _ = probability[q["qId"]]
        values[q["qId"]] = p * q["Points"]
    live = [v for v in values.values() if v > 0]
    mean_value = sum(live) / len(live)

    correctness = {
        q["qId"]: [bool(c["isCorrect"]) for c in q["Choices"]] for q in questions
    }
    # Serbian text only — the exam is written in Serbian, and the answer options
    # on the question screen are always shown in Serbian (a translation is an
    # optional gloss underneath), so a cue must be a Serbian wording.
    catalogue = {q["qId"]: [c["Text"] for c in q["Choices"]] for q in questions}
    stems = {q["qId"]: q["Text"] for q in questions}

    markers, marker_hits, base = _markers(catalogue, correctness)
    links, link_hits = _links(catalogue, stems, correctness)
    stats = {
        "correctOptionRate": round(base, 4),
        "markerQuestions": len(marker_hits),
        "linkQuestions": len(link_hits),
    }

    out_questions = {}
    for q in questions:
        qid = q["qId"]
        p, pool_id = probability[qid]
        pool = pools[pool_id]
        value = values[qid]
        entry = {
            "p": round(p, 6),
            "points": q["Points"],
            "value": round(value, 6),
            "tier": _tier(value, mean_value),
            "ratio": round(value / mean_value, 3) if mean_value else 0.0,
            "poolSize": pool["size"],
            "poolSlots": pool["slots"],
            "sampleHits": seen.get(qid, 0),
        }
        hits = marker_hits.get(qid)
        if hits:
            entry["markers"] = sorted(hits, key=lambda h: (h["c"], h["m"]))
        hits = link_hits.get(qid)
        if hits:
            entry["links"] = sorted(hits, key=lambda h: (h["c"], h["l"]))
        out_questions[str(qid)] = entry

    document = {
        "schema": SCHEMA_VERSION,
        "source": {
            "exams": len(exams),
            "examSize": len(exams[0]),
            "examPoints": round(
                statistics.mean(
                    sum(
                        {q["qId"]: q["Points"] for q in questions}[qid] for qid in exam
                    )
                    for exam in exams
                ),
                2,
            ),
            "questions": len(questions),
            "meanValue": round(mean_value, 6),
        },
        "stats": stats,
        "markers": markers,
        "links": links,
        "questions": out_questions,
    }

    if verify:
        _verify(questions, exams, pools, probability, values, document)
    return document


def _tier(value: float, mean_value: float) -> str:
    """High / medium / low, cut at 2× and ½× the average question's worth.

    Questions from category 38 (never drawn by the exam) come out at 0 and get
    their own tier — calling them "low" would imply they might still show up.
    """
    if value <= 0:
        return "none"
    if value >= 2 * mean_value:
        return "high"
    if value >= 0.5 * mean_value:
        return "medium"
    return "low"


def _verify(questions, exams, pools, probability, values, document):
    """Print the checks the model rests on, so it can be re-audited on new data."""
    points = {q["qId"]: q["Points"] for q in questions}
    by_pool = collections.defaultdict(list)
    pool_of = {}
    for pool_id, pool in pools.items():
        for sub in pool["subcategories"]:
            pool_of[sub] = pool_id
    for q in questions:
        by_pool[pool_of[q["subcategoryId"]]].append(q["qId"])

    seen = collections.Counter()
    for exam in exams:
        seen.update(exam)

    print(f"exams: {len(exams)} × {len(exams[0])} questions")
    print(f"pools: {len(pools)}, slots total: {sum(p['slots'] for p in pools.values())}")
    print()
    print("uniformity within each pool (chi-square / df should sit near 1.0):")
    worst = 0.0
    for pool_id, qids in sorted(by_pool.items()):
        pool = pools[pool_id]
        if pool["slots"] == 0 or len(qids) < 3:
            continue
        expected = pool["slots"] * len(exams) / len(qids)
        chi = sum((seen.get(q, 0) - expected) ** 2 / expected for q in qids)
        ratio = chi / (len(qids) - 1)
        worst = max(worst, abs(ratio - 1))
        print(
            f"  {pool_id:>6}  n={len(qids):>4}  k={pool['slots']}  "
            f"expected={expected:6.2f}  chi2/df={ratio:5.2f}"
        )
    print(f"  worst deviation from 1.0: {worst:.2f}")
    print()

    modelled = sum(probability[q["qId"]][0] for q in questions)
    print(f"expected questions per exam (model): {modelled:.3f} vs actual {len(exams[0])}")
    modelled_points = sum(values.values())
    actual_points = statistics.mean(sum(points[q] for q in exam) for exam in exams)
    print(
        f"expected points per exam (model): {modelled_points:.3f} vs actual "
        f"{actual_points:.3f}"
    )
    never = [q["qId"] for q in questions if seen.get(q["qId"], 0) == 0]
    unreachable = [q for q in never if probability[q][0] == 0]
    print(
        f"questions absent from the sample: {len(never)}, of which unreachable by the "
        f"model: {len(unreachable)}"
    )
    tiers = collections.Counter(e["tier"] for e in document["questions"].values())
    print(f"value tiers: {dict(tiers)}")
    print()
    print(
        f"markers: {len(document['markers'])}, links: {len(document['links'])}, "
        f"{document['stats']}"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="print the model checks")
    parser.add_argument("--stdout", action="store_true", help="do not write the asset")
    args = parser.parse_args()

    document = build(verify=args.verify)
    if args.stdout:
        json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
        return
    with open(OUTPUT, "w", encoding="utf-8") as fh:
        json.dump(document, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    print(f"wrote {OUTPUT.relative_to(OUTPUT.parent.parent)} "
          f"({OUTPUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
