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
3. **Keyword analysis** — phrases in the answer options whose correctness is
   decided across the whole question bank, plus the two classic option-shape
   heuristics (option length, overlap with the question stem).

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

SCHEMA_VERSION = 1

# ---------------------------------------------------------------------------
# Exam model
# ---------------------------------------------------------------------------

# A phrase must occur in at least this many answer options before its
# correct/wrong record is worth reporting: below that, "always correct" is just
# a small-sample accident.
MIN_MARKER_OPTIONS = 8
# A phrase that does not decide *every* option it appears in still counts when
# it is this lopsided — reported as "почти всегда" with the raw tally, never as
# a rule.
MOSTLY_CORRECT_RATE = 0.85
MOSTLY_WRONG_RATE = 0.08
# Longest phrase considered, in words.
MAX_MARKER_WORDS = 4
# One-sided binomial tail against the base rate; anything weaker is noise.
MARKER_MAX_P_VALUE = 1e-3


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

# Function words carry no exam signal, and letting them into n-grams buries the
# real phrases under "и на путу"-style noise. Serbian (Cyrillic and Latin) and
# Russian, since the two catalogues are analysed separately.
STOPWORDS = {
    # sr
    "и", "или", "а", "али", "да", "не", "је", "су", "се", "би", "бити", "сам",
    "у", "на", "од", "до", "за", "са", "код", "по", "из", "о", "об", "уз", "низ",
    "пре", "после", "при", "кроз", "ка", "к", "те", "тако", "као", "што", "који",
    "која", "које", "којих", "којим", "коју", "ако", "већ", "још", "само", "сваки",
    "свака", "свако", "тај", "та", "то", "тог", "тим", "ово", "овај", "ова",
    "оних", "они", "оне", "она", "он", "му", "им", "их", "ме", "мора", "може",
    "i", "ili", "a", "ali", "da", "ne", "je", "su", "se", "u", "na", "od", "do",
    "za", "sa", "po", "iz", "o", "pre", "posle", "pri", "kroz", "kao", "sto",
    # ru
    "в", "во", "на", "с", "со", "по", "из", "за", "к", "ко", "от", "до", "для",
    "при", "об", "о", "у", "и", "или", "а", "но", "что", "как", "если", "то",
    "же", "бы", "ли", "не", "ни", "быть", "есть", "это", "этот", "эта", "эти",
    "тот", "та", "те", "который", "которая", "которые", "которых", "которым",
    "его", "их", "ее", "её", "он", "она", "они", "может", "можно", "должен",
    "должна", "должны", "также", "только", "уже", "еще", "ещё", "все", "всех",
}


def _tokens(text: str):
    return [t for t in _WORD.split(text.lower()) if t]


def _ngrams(text: str):
    """Content n-grams of a piece of text, 1..MAX_MARKER_WORDS words.

    An n-gram may not start or end on a stopword (`"у случају"` is a phrase,
    `"у"` and `"случају у"` are not), which keeps the candidate set to phrases a
    person would recognise as one.
    """
    words = _tokens(text)
    out = set()
    for n in range(1, MAX_MARKER_WORDS + 1):
        for i in range(len(words) - n + 1):
            gram = words[i : i + n]
            if gram[0] in STOPWORDS or gram[-1] in STOPWORDS:
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


def _markers(catalogue, correctness):
    """Phrases whose presence in an answer option decides that option.

    `catalogue` is `qId -> [option text]` in the language being analysed and
    `correctness` is `qId -> [bool]` (taken from the Serbian catalogue, which is
    the only one carrying `isCorrect`).

    A phrase is reported when it occurs in at least `MIN_MARKER_OPTIONS` options
    across the bank, its options are all correct / all wrong (or lopsided enough
    to pass `MOSTLY_*_RATE`), and that record is unlikely under the base rate —
    only about 36% of options are correct, so 25 wrong ones in a row is not a
    coincidence. Longer restatements of a phrase already kept are dropped.
    """
    options = []  # (qId, choice index, is correct)
    holders = collections.defaultdict(set)  # phrase -> option indices
    for qid, texts in catalogue.items():
        for idx, text in enumerate(texts):
            option = len(options)
            options.append((qid, idx, correctness[qid][idx]))
            for gram in _ngrams(text):
                holders[gram].add(option)

    base = sum(1 for _, _, ok in options if ok) / len(options)

    found = []
    for phrase, owners in holders.items():
        n = len(owners)
        if n < MIN_MARKER_OPTIONS:
            continue
        correct = sum(1 for o in owners if options[o][2])
        rate = correct / n
        if rate == 1.0:
            kind, p_value = "alwaysCorrect", _binom_tail(correct, n, base)
        elif rate == 0.0:
            kind, p_value = "alwaysWrong", _binom_tail(n - correct, n, 1 - base)
        elif rate >= MOSTLY_CORRECT_RATE:
            kind, p_value = "mostlyCorrect", _binom_tail(correct, n, base)
        elif rate <= MOSTLY_WRONG_RATE:
            kind, p_value = "mostlyWrong", _binom_tail(n - correct, n, 1 - base)
        else:
            continue
        if p_value > MARKER_MAX_P_VALUE:
            continue
        found.append(
            {
                "phrase": phrase,
                "kind": kind,
                "options": n,
                "correct": correct,
                "owners": owners,
                "pValue": p_value,
            }
        )

    # Prefer the shortest phrasing of the same rule: "потреба" and "постоји
    # потреба" pointing at the same options is one finding, not two. A longer
    # phrase survives only when it decides options the short one does not.
    found.sort(key=lambda m: (len(m["phrase"].split()), len(m["phrase"])))
    kept = []
    for marker in found:
        if any(
            k["kind"] == marker["kind"]
            and k["phrase"] in marker["phrase"]
            and marker["owners"] <= k["owners"]
            for k in kept
        ):
            continue
        kept.append(marker)

    kept.sort(key=lambda m: (-m["options"], m["phrase"]))
    per_question = collections.defaultdict(list)
    catalog = []
    for index, marker in enumerate(kept):
        catalog.append(
            {
                "phrase": marker["phrase"],
                "kind": marker["kind"],
                "options": marker["options"],
                "correct": marker["correct"],
            }
        )
        for owner in marker["owners"]:
            qid, choice, _ = options[owner]
            per_question[qid].append({"m": index, "c": choice})
    return catalog, per_question, base


def _shape_stats(catalogue, correctness):
    """The two option-shape heuristics, measured over the whole bank.

    * **length** — is the longest option of a question the correct one more often
      than chance (1 / number of options)?
    * **stem overlap** — does an option that repeats a content word from the
      question stem end up correct more often than the base rate?

    Both are reported as measured rates so the UI can state them honestly
    ("работает в 38% вопросов при случайных 33%") instead of selling a rule of
    thumb as a law.
    """
    longest_hits = longest_total = 0
    longest_chance = 0.0
    overlap_correct = overlap_total = 0
    plain_correct = plain_total = 0

    for qid, texts in catalogue.items():
        flags = correctness[qid]
        if len(texts) < 2:
            continue
        lengths = [len(t) for t in texts]
        top = max(lengths)
        if lengths.count(top) == 1:
            longest_total += 1
            longest_chance += sum(flags) / len(texts)
            if flags[lengths.index(top)]:
                longest_hits += 1

    return {
        "longestOptionCorrect": round(longest_hits / longest_total, 4)
        if longest_total
        else 0.0,
        "longestOptionChance": round(longest_chance / longest_total, 4)
        if longest_total
        else 0.0,
        "longestOptionQuestions": longest_total,
    }


def _stem_overlap(catalogue, stems, correctness):
    """Does an option echoing the question's wording tend to be the right one?"""
    with_overlap_correct = with_overlap = without_correct = without = 0
    per_question = {}
    for qid, texts in catalogue.items():
        stem_words = {w for w in _tokens(stems[qid]) if w not in STOPWORDS and len(w) > 3}
        echoes = []
        for idx, text in enumerate(texts):
            words = {w for w in _tokens(text) if w not in STOPWORDS and len(w) > 3}
            shared = stem_words & words
            if shared:
                echoes.append(idx)
                with_overlap += 1
                with_overlap_correct += correctness[qid][idx]
            else:
                without += 1
                without_correct += correctness[qid][idx]
        if echoes:
            per_question[qid] = echoes
    return (
        {
            "echoCorrectRate": round(with_overlap_correct / with_overlap, 4)
            if with_overlap
            else 0.0,
            "noEchoCorrectRate": round(without_correct / without, 4) if without else 0.0,
            "echoOptions": with_overlap,
        },
        per_question,
    )


# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------


def build(verify: bool = False):
    questions = load("allQuestions.json")
    questions_ru = {q["qId"]: q for q in load("allQuestions_ru.json")}
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
    catalogues = {
        "sr": {q["qId"]: [c["Text"] for c in q["Choices"]] for q in questions},
        "ru": {
            q["qId"]: [c["Text"] for c in questions_ru[q["qId"]]["Choices"]]
            for q in questions
        },
    }
    stems = {
        "sr": {q["qId"]: q["Text"] for q in questions},
        "ru": {q["qId"]: questions_ru[q["qId"]]["Text"] for q in questions},
    }

    markers = {}
    marker_hits = {}
    echoes = {}
    stats = {}
    for locale, catalogue in catalogues.items():
        catalog, per_question, base = _markers(catalogue, correctness)
        markers[locale] = catalog
        marker_hits[locale] = per_question
        shape = _shape_stats(catalogue, correctness)
        overlap, per_q_echo = _stem_overlap(catalogue, stems[locale], correctness)
        echoes[locale] = per_q_echo
        stats[locale] = {**shape, **overlap, "correctOptionRate": round(base, 4)}

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
        for locale in catalogues:
            hits = marker_hits[locale].get(qid)
            if hits:
                entry.setdefault("markers", {})[locale] = sorted(
                    hits, key=lambda h: (h["c"], h["m"])
                )
            echo = echoes[locale].get(qid)
            if echo:
                entry.setdefault("echo", {})[locale] = echo
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
    for locale, stat in document["stats"].items():
        print(f"[{locale}] markers: {len(document['markers'][locale])}, {stat}")


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
