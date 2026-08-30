#!/usr/bin/env python3
"""Вливает готовые переводы чанков в assets/parsed_pravilnik.json.

Собирает словарь sr→ru из chunks/*.json + ru/*.json, добавляет
«механические» переводы (коды знаков как есть, «Члан N.» → «Статья N.»)
и заполняет поле ru у всех записей. Падает, если хоть одна строка
осталась без перевода или разметка перевода разошлась с оригиналом.
"""
import json
import re
import sys
from pathlib import Path

from prepare_chunks import ASSET, OUT, mechanical_ru

RU_DIR = Path(__file__).resolve().parent / 'ru'

# Сербские буквы, которых нет в русском: перевод не должен их содержать
# (латиница в кодах знаков — можно).
SERBIAN_ONLY = re.compile(r'[ђјљњћџЂЈЉЊЋЏ]')


def main():
    sr2ru = {}
    problems = []
    for chunk_file in sorted(OUT.glob('chunk_*.json')):
        ru_file = RU_DIR / chunk_file.name
        if not ru_file.exists():
            problems.append(f'нет файла перевода {ru_file.name}')
            continue
        src = json.loads(chunk_file.read_text())
        dst = json.loads(ru_file.read_text())
        if len(src) != len(dst):
            problems.append(
                f'{chunk_file.name}: {len(src)} строк в оригинале, '
                f'{len(dst)} в переводе')
            continue
        for sr, ru in zip(src, dst):
            if not sr.strip():
                continue  # переводится механически (см. mechanical_ru)
            if not isinstance(ru, str) or not ru.strip():
                problems.append(f'{chunk_file.name}: пустой перевод {sr[:60]!r}')
                continue
            # Разметка должна сохраниться: же число ** и заголовочный ###.
            if sr.count('**') != ru.count('**'):
                problems.append(
                    f'{chunk_file.name}: разошлись ** у {sr[:60]!r}')
            if sr.startswith('#') != ru.startswith('#'):
                problems.append(
                    f'{chunk_file.name}: разошлись заголовки у {sr[:60]!r}')
            if SERBIAN_ONLY.search(ru) and not SERBIAN_ONLY.search(sr):
                problems.append(
                    f'{chunk_file.name}: сербские буквы в переводе '
                    f'{ru[:60]!r}')
            sr2ru[sr] = ru

    entries = json.loads(ASSET.read_text())
    missing = []
    for e in entries:
        sr = e['sr']
        ru = mechanical_ru(sr)
        if ru is None:
            # Перевод из чанков, иначе — уже стоявший в JSON (строка пережила
            # смену редакции документа, см. prepare_chunks.py).
            ru = sr2ru.get(sr) or (e.get('ru') or '').strip() or None
        if ru is None:
            missing.append(sr)
        else:
            e['ru'] = ru
    if missing:
        problems.append(f'{len(missing)} строк без перевода, например '
                        f'{missing[:3]!r}')

    if problems:
        print('ПРОБЛЕМЫ:')
        for p in problems:
            print(' -', p)
        sys.exit(1)

    ASSET.write_text(
        json.dumps(entries, ensure_ascii=False, indent=1) + '\n')
    print(f'ok: {len(entries)} записей, ru заполнено у всех')


if __name__ == '__main__':
    main()
