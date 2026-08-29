#!/usr/bin/env python3
"""Готовит куски правилника для перевода на русский.

Читает assets/parsed_pravilnik.json, отделяет «механические» строки
(коды знаков, «Члан N.»), а остальные уникальные sr-строки режет на
чанки для параллельного перевода. Каждый чанк — JSON-массив строк.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSET = ROOT / 'assets' / 'parsed_pravilnik.json'
OUT = Path(__file__).resolve().parent / 'chunks'

CODE_RE = re.compile(r'^\*\*[IVX]+ ?-[\d.а-шђјљњћџa-z ()]+\*\*$')
CHLAN_RE = re.compile(r'^Члан (\d+)\.$')


def mechanical_ru(sr: str):
    """Перевод для строк, не требующих модели; None если нужен настоящий."""
    if not sr.strip():
        return sr  # строка-контейнер для картинок, текста в ней нет
    if CODE_RE.match(sr):
        return sr  # код знака — одинаков в обоих языках
    m = CHLAN_RE.match(sr)
    if m:
        return f'Статья {m.group(1)}.'
    return None


def main():
    n_chunks = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    entries = json.loads(ASSET.read_text())
    uniq = []
    seen = set()
    for e in entries:
        sr = e['sr']
        if sr in seen:
            continue
        seen.add(sr)
        if mechanical_ru(sr) is None:
            uniq.append(sr)
    total = sum(len(s) for s in uniq)
    print(f'to translate: {len(uniq)} strings, {total} chars')

    OUT.mkdir(exist_ok=True)
    for f in OUT.glob('chunk_*.json'):
        f.unlink()
    # Режем по бюджету символов, сохраняя порядок документа (контекст для
    # переводчика: соседние строки — соседние абзацы).
    budget = total / n_chunks + 1
    chunks, cur, cur_len = [], [], 0
    for s in uniq:
        if cur and cur_len + len(s) > budget:
            chunks.append(cur)
            cur, cur_len = [], 0
        cur.append(s)
        cur_len += len(s)
    if cur:
        chunks.append(cur)
    for i, ch in enumerate(chunks):
        p = OUT / f'chunk_{i:02d}.json'
        p.write_text(json.dumps(ch, ensure_ascii=False, indent=1))
        print(p.name, len(ch), 'strings', sum(len(s) for s in ch), 'chars')


if __name__ == '__main__':
    main()
