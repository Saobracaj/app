#!/usr/bin/env python3
"""Проверяет связку «виджет-иллюстрация ↔ текст».

Запускать из каталога app/:

    python3 .claude/skills/illustration-widget/tools/check_illustrations.py

Что показывает:
  ОШИБКИ   — маркер anim/<slug> в тексте, но слаг не зарегистрирован в
             animations_map.dart (в приложении будет «Animation not found»);
           — файл виджета без регистрации в карте.
  ПРЕДУПР. — слаг зарегистрирован, но нигде не используется.
  ОЧЕРЕДЬ  — оставшиеся плейсхолдеры illustration:<slug> в конспектах: на их
             месте в приложении показывается серая плашка-заглушка.

Комментарии-объяснения хранятся в БД бэкенда, скрипт их не видит.
Только stdlib.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[4]
MAP = APP / "lib/test/animations/animations_map.dart"
ANIM_DIR = APP / "lib/test/animations"
KONSPEKT_DIR = APP / "konspekt_content"

ANIM_MARKER = re.compile(r"!\[[^\]]*\]\(anim/([a-zA-Z0-9._-]+)\)")
PLACEHOLDER = re.compile(r"!\[[^\]]*\]\(illustration:([a-zA-Z0-9._-]+)\)")
MAP_ENTRY = re.compile(r"^\s*'([^']+)'\s*:\s*(\w+)\(", re.M)


def registered() -> dict[str, str]:
    """слаг -> имя класса виджета."""
    if not MAP.exists():
        sys.exit(f"не найден {MAP}")
    return {m.group(1): m.group(2) for m in MAP_ENTRY.finditer(MAP.read_text())}


def konspekt_usage() -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """Маркеры anim/… и плейсхолдеры illustration:… по файлам конспектов."""
    used: dict[str, list[str]] = {}
    todo: dict[str, list[str]] = {}
    for path in sorted(KONSPEKT_DIR.glob("*.json")):
        raw = path.read_text()
        for slug in set(ANIM_MARKER.findall(raw)):
            used.setdefault(slug, []).append(path.name)
        for slug in set(PLACEHOLDER.findall(raw)):
            todo.setdefault(slug, []).append(path.name)
        # illustrations[] — ТЗ, которое положено удалять вместе с плейсхолдером
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as err:
            print(f"[warn] {path.name}: не разбирается как JSON ({err})")
            continue
        for section in data.get("sections", []):
            for item in section.get("illustrations", []) or []:
                slug = item.get("id") or item.get("slug")
                if slug and slug not in todo:
                    todo.setdefault(slug, []).append(f"{path.name} (только illustrations[])")
    return used, todo


def widget_files() -> dict[str, Path]:
    """slug_snake -> файл (эвристика по имени файла)."""
    return {p.stem: p for p in ANIM_DIR.glob("*.dart") if p.name != "animations_map.dart"}


def main() -> int:
    reg = registered()
    used, todo = konspekt_usage()
    files = widget_files()

    errors: list[str] = []
    warnings: list[str] = []

    for slug, where in sorted(used.items()):
        if slug not in reg:
            errors.append(
                f"маркер anim/{slug} ({', '.join(where)}) — слаг не зарегистрирован "
                f"в animations_map.dart"
            )

    for slug, cls in sorted(reg.items()):
        snake = slug.replace("-", "_")
        if snake not in files and slug not in files:
            warnings.append(f"слаг '{slug}' → {cls}: файла {snake}.dart нет (виджет живёт в другом файле?)")
        if slug not in used:
            warnings.append(f"слаг '{slug}' зарегистрирован, но не встречается в конспектах")

    print(f"Зарегистрировано слагов: {len(reg)}")
    print(f"Использовано в конспектах: {len(used)}")
    print(f"Осталось плейсхолдеров: {len(todo)}")
    print()

    if errors:
        print("ОШИБКИ")
        for line in errors:
            print(f"  ✗ {line}")
        print()
    if warnings:
        print("ПРЕДУПРЕЖДЕНИЯ")
        for line in warnings:
            print(f"  · {line}")
        print()
    if todo:
        print("ОЧЕРЕДЬ (плейсхолдеры illustration:… — серая плашка в приложении)")
        for slug, where in sorted(todo.items()):
            print(f"  – {slug}: {', '.join(sorted(where))}")
        print()

    if not errors:
        print("OK: битых ссылок нет")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
