#!/usr/bin/env python3
"""Переносит ссылки `pravilnik?chapter=…&chlan=…&paragraph=N` в объяснениях
на новую нумерацию абзацев после перегенерации assets/parsed_pravilnik.json.

Абзац правилника адресуется порядковым номером строки внутри члена. Когда
растровый рисунок docx заменяется официальным SVG, под знаком появляется
строка-подпись («**III-24**»), и все строки члена ниже сдвигаются на одну.
Ссылки из объяснений к вопросам (saobracaj_comments.text, см. задачу
1217991328130147) при этом начинают указывать на соседнюю строку.

Скрипт сравнивает старый и новый JSON, сопоставляет текстовые строки каждого
члена по сербскому тексту и печатает SQL (plpgsql DO-блок) с картой
«старый номер → новый». Замена делается за один проход через временную
пометку `~N~`, чтобы цепочка 60→61→62 не сработала дважды. Запускать ОДИН
раз на каждую БД (прод и dev) в момент выкатки сборки с новым JSON — старые
клиенты с прежним JSON после этого промахиваются на те же строки, что новые
клиенты до него; в один заход не бывает.

    python3 tool/remap_pravilnik_links.py \
        --old <(git show main:assets/parsed_pravilnik.json) \
        --new assets/parsed_pravilnik.json > /tmp/remap.sql
    # затем psql -U saobracaj -d saobracaj_backend -f /tmp/remap.sql
"""

import argparse
import hashlib
import json
import sys


def text_rows(rows, chapter, chlan):
    return [r for r in rows
            if r.get('chapter') == chapter and r.get('chlan') == chlan and r.get('sr')]


def mapping(old, new):
    """{(chapter, chlan): [(old_paragraph, new_paragraph), …]} — только сдвиги."""
    result = {}
    keys = []
    for r in old:
        key = (r.get('chapter'), r.get('chlan'))
        if key not in keys:
            keys.append(key)
    for chapter, chlan in keys:
        o_rows = text_rows(old, chapter, chlan)
        n_rows = text_rows(new, chapter, chlan)
        pairs = []
        ni = 0
        for r in o_rows:
            while ni < len(n_rows) and n_rows[ni]['sr'] != r['sr']:
                ni += 1
            if ni == len(n_rows):
                print(f'нет пары для {chapter} чл.{chlan} абз.{r["paragraph"]}: '
                      f'{r["sr"][:60]!r}', file=sys.stderr)
                break
            if r['paragraph'] != n_rows[ni]['paragraph']:
                pairs.append((int(r['paragraph']), int(n_rows[ni]['paragraph'])))
            ni += 1
        if pairs:
            result[(chapter, chlan)] = pairs
    return result


SQL = r"""-- Сгенерировано tool/remap_pravilnik_links.py.
-- Повторный запуск сдвинул бы ссылки ещё раз, поэтому каждый перенос
-- записывается в saobracaj_maintenance_runs и второй раз не выполняется.
BEGIN;
CREATE TABLE IF NOT EXISTS saobracaj_maintenance_runs (
  key text PRIMARY KEY,
  ran_at timestamptz NOT NULL DEFAULT now()
);
DO $$
DECLARE
  pairs int[][] := ARRAY[{pairs}];
  chapter text := '{chapter}';
  chlan text := '{chlan}';
  run_key text := '{key}';
  prefix text;
  r record;
  s text;
  i int;
  changed int := 0;
BEGIN
  IF EXISTS (SELECT 1 FROM saobracaj_maintenance_runs WHERE key = run_key) THEN
    RAISE NOTICE 'перенос % уже выполнялся — пропуск', run_key;
    RETURN;
  END IF;
  INSERT INTO saobracaj_maintenance_runs (key) VALUES (run_key);
  prefix := 'pravilnik?chapter=' || chapter || '&chlan=' || chlan || '&paragraph=';
  FOR r IN SELECT question_id, text::text AS s FROM saobracaj_comments
           WHERE text::text LIKE '%' || prefix || '%' LOOP
    s := r.s;
    FOR i IN 1 .. array_length(pairs, 1) LOOP
      s := regexp_replace(
        s,
        regexp_replace(prefix, '([?&.])', '\\\1', 'g') || pairs[i][1] || '(?![0-9])',
        prefix || '~' || pairs[i][2] || '~',
        'g');
    END LOOP;
    s := regexp_replace(s, regexp_replace(prefix, '([?&.])', '\\\1', 'g') || '~([0-9]+)~',
                        prefix || '\1', 'g');
    IF s <> r.s THEN
      UPDATE saobracaj_comments SET text = s::jsonb, updated_at = now()
       WHERE question_id = r.question_id;
      changed := changed + 1;
    END IF;
  END LOOP;
  RAISE NOTICE 'чл.% : обновлено объяснений: %', chlan, changed;
END $$;
COMMIT;
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--old', required=True)
    ap.add_argument('--new', required=True)
    args = ap.parse_args()
    old = json.load(open(args.old, encoding='utf-8'))
    new = json.load(open(args.new, encoding='utf-8'))
    shifts = mapping(old, new)
    if not shifts:
        print('-- сдвигов нет', file=sys.stderr)
        return
    for (chapter, chlan), pairs in shifts.items():
        print(f'{chapter} чл.{chlan}: сдвинуто {len(pairs)} абзацев '
              f'({pairs[0][0]}→{pairs[0][1]} … {pairs[-1][0]}→{pairs[-1][1]})',
              file=sys.stderr)
        pairs_sql = ', '.join(f'[{a},{b}]' for a, b in pairs)
        digest = hashlib.sha1(f'{chapter}/{chlan}/{pairs_sql}'.encode()).hexdigest()[:12]
        print(SQL.format(
            chapter=chapter, chlan=chlan, pairs=pairs_sql,
            key=f'pravilnik-links-{chapter}-{chlan}-{digest}'))


if __name__ == '__main__':
    main()
