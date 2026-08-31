#!/usr/bin/env python3
"""Собирает assets/parsed_pravilnik.json и assets/pravilnik/* из docx правилника.

Источник — tool/data/pravilnik_o_saobracajnoj_signalizaciji.docx: редакционно
очищенный текст «Правилника о саобраћајној сигнализацији» («Службени гласник
РС», бр. 85/2017, 14/2021, 21/2024, 76/2026) с сайта pravno-informacioni-
sistem.rs. В нём нет ни стилей абзацев, ни таблиц: структура читается из
самого текста (главы «I. ОСНОВНЕ ОДРЕДБЕ», подзаголовки по центру, «Члан N.»),
а знаки — растровые картинки, по одной на строку перечисления.

JSON повторяет схему assets/parsed_zakon.json (chapter/chlan/paragraph/sr/ru/
isTitle) и добавляет опциональное поле images — список изображений строки
({src, w, h}; w/h — размер из docx в px, чтобы приложение показывало рисунок
в натуральную величину документа). Адресация строк (chapter+chlan+paragraph)
даёт те же ссылки, что и в законе: /pravilnik?chapter=…&chlan=…&paragraph=…

Знаки. В docx один рисунок содержит все знаки пункта разом (и их коды,
впечатанные под каждым знаком). Коды берутся из текста пункта — «знак
„кривина налево” (I-1) и знак „кривина надесно” (I-1.1)», — и если для КАЖДОГО
кода в assets/signs/ есть официальный SVG (файлы названы по нумерации
правилника 2017 года — той же, что в этом документе), рисунок docx не
сохраняется вовсе: строка получает по картинке на код, а под ней встаёт
строка-подпись «**I-1 I-1.1**», из которой экран строит подписи под знаками.
Иначе (новые знаки 2017 года, разметка, семафоры, схемы) в assets/pravilnik/
кладётся сам растр из docx: коды на нём уже впечатаны, подпись не нужна.

Запуск из корня app/:  python3 tool/parse_pravilnik.py
"""

import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
WP = '{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}'
R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, 'tool', 'data', 'pravilnik_o_saobracajnoj_signalizaciji.docx')
OUT_JSON = os.path.join(ROOT, 'assets', 'parsed_pravilnik.json')
OUT_DIR = os.path.join(ROOT, 'assets', 'pravilnik')
SIGNS_DIR = os.path.join(ROOT, 'assets', 'signs')

EMU_PER_PX = 9525  # 96 dpi

# Размер картинки по умолчанию: в нескольких местах docx потерял wp:extent и
# отдаёт квадрат 524.9×524.9 px — знак в натуральную величину примерно такой.
BROKEN_EXTENT = 524.9
DEFAULT_SIGN_W = 128.0
DEFAULT_SIGN_H = 142.7

# Строка «Преузето са …» и пометка редакции — служебные строки выгрузки.
SKIP_LINES = {
    'Преузето са https://pravno-informacioni-sistem.rs',
    'Редакцијски пречишћен текст',
}

# Заголовок главы: «I. ОСНОВНЕ ОДРЕДБЕ».
CHAPTER_RE = re.compile(r'^([IVX]+)\.\s+(.+)$')
# Заголовок члена: «Члан 7.», «Члан 53а.»; звёздочки — пометки об изменениях.
CHLAN_RE = re.compile(r'^Члан\s+(\d+[а-шђјљњћџ]?)\.?\**\s*$')
# Приложение к пречишћеном тексту: дальше идут члены самих законов об
# изменениях, их номера повторяют основные — адреса им не выдаём.
APPENDIX_RE = re.compile(r'^ОДРЕДБЕ КОЈЕ НИСУ УНЕТЕ')

# Код знака в тексте пункта: «(I-1)», «знакови II-43.2 и III-84». Римская
# часть — до четырёх букв: главы доходят до VIII (опрема пута), и на «трёх»
# из «(VIII-1)» читалось бы «III-1», подставляя под определение смероказа
# знак «трака за возила јавног превоза».
CODE_RE = re.compile(r'\b[IVX]{1,4}-\d+(?:\.\d+)*')
# Код в формате определения — сразу за открывающей скобкой. Пункт называет
# нарисованные знаки именно так («допунске табле (IV-10), (IV-11) и (IV-12)»),
# а прочие упоминания («које се регулише знаком III-30») к рисунку не
# относятся, поэтому скобочные коды имеют приоритет.
CODE_PAREN_RE = re.compile(r'\(\s*([IVX]{1,4}-\d+(?:\.\d+)*)')

# Варианты имён файла в assets/signs/ для кода правилника. Первый совпавший и
# берётся: «-2017» — знак образца 2017 года там, где базовое имя занято
# знаком из правилника 2010 года; «-40»/«-70» — знак с конкретным числом
# (ограничение брзине), «c» — вариант рисунка.
SIGN_SUFFIXES = ('-2017', '', '-40', '-70', 'c')

# Знаки, у которых имя файла НЕ совпадает с кодом этого документа. Файлы в
# assets/signs/ названы по нумерации Викисклада, а она местами разошлась с
# правилником 2017 года: «престанак забране претицања» лежит в iii-25.svg,
# хотя в документе это III-12. Сверено попиксельно с рисунками docx (растр
# стоит в документе рядом с кодом), задача 1203867458890010.
CODE_OVERRIDES = {
    'III-3.1': 'iii-4',        # завршетак првенства пролаза
    'III-4': 'iii-79',         # успорење саобраћаја (издигнута површина)
    'III-12': 'iii-25',        # престанак забране претицања
    'III-13': 'iii-26-kraj',   # престанак забране претицања за теретна возила
    'III-57': 'iii-54',        # стање пролаза («Црни Врх — отворен»)
    'III-58': 'iii-57',        # планински превој («Рудник 651 m.n.m.»)
    'III-59': 'iii-55',        # надморска висина («984 m.n.m.»)
    'III-69': 'iii-21',        # пут резервисан за моторна возила (мотопут)
    'III-69.1': 'iii-22',      # завршетак мотопута
    'III-71': 'iii-69',        # трака за возила јавног превоза
    'III-71.1': 'iii-69.1',    # завршетак траке за возила јавног превоза
    'III-72': 'iii-71',        # трака за спора возила
}

# Коды, у которых одноимённый файл в assets/signs/ — ДРУГОЙ знак, а верного
# вектора нет вовсе: подставлять нечего, строка остаётся рисунком самого
# документа. Занявшие эти имена файлы стоят в документе под своими кодами
# (CODE_OVERRIDES). Список дублирует misnumberedFiles в
# lib/zakon/domain/road_sign_index.dart — синхронность проверяет тест.
WRONG_SIGN = {
    'III-21',   # завршетак стазе за бициклисте и пешаке (iii-21 = мотопут)
    'III-22',   # завршетак стазе за јахаче (iii-22 = крај мотопута)
    'III-54',   # WC (iii-54 = стање пролаза)
    'III-55',   # радио станица (iii-55 = надморска висина)
    'III-74',   # трака за одређену врсту возила (iii-83 — с лишним символом)
    'III-76',   # престројавање на аутопуту (iii-76 = путоказ за излаз)
    'III-79',   # трака за возила (iii-79 = успорење саобраћаја)
    'III-83',   # предзнак за престројавање (iii-83 = трака за врсту возила)
}

# Тот же знак, но официальный вектор нарисован иначе, чем в правилнике:
# рисунок документа вернее.
WRONG_DRAWING = {
    'IV-22',    # оштећен коловоз: в iv-22 вписана лишняя надпись «КОЛОТРАЗИ»
}

NO_OFFICIAL = WRONG_SIGN | WRONG_DRAWING


def para_text(p):
    """Текст абзаца одной строкой (мягкие переносы docx схлопываются)."""
    return re.sub(
        r'\s+', ' ', ''.join(t.text or '' for t in p.iter(W + 't'))).strip()


def md_escape(text):
    """Экранирует звёздочки-сноски: «је* саобраћајна», «четвороцикле**».

    Документ помечает ими изменённые места, а Markdown принял бы их за
    выделение и съел кусок текста.
    """
    return text.replace('*', r'\*')


class SignFiles:
    """Официальные SVG знаков: код правилника → assets/signs/<файл>.svg."""

    def __init__(self):
        self.names = {f[:-4] for f in os.listdir(SIGNS_DIR)
                      if f.endswith('.svg')}
        missing = set(CODE_OVERRIDES.values()) - self.names
        assert not missing, f'нет файлов из CODE_OVERRIDES: {sorted(missing)}'

    def resolve(self, code):
        if code in NO_OFFICIAL:
            return None
        if code in CODE_OVERRIDES:
            return f'assets/signs/{CODE_OVERRIDES[code]}.svg'
        base = code.lower()
        for suffix in SIGN_SUFFIXES:
            if base + suffix in self.names:
                return f'assets/signs/{base}{suffix}.svg'
        return None


class Parser:
    def __init__(self, doc_root, media, signs):
        self.media = media  # rel id -> (bytes, ext)
        self.signs = signs
        self.rows = []
        self.chapter = None
        self.chlan = None
        self.par_no = 0
        self.appendix = False
        self.assets = {}  # content hash -> asset file name
        self.asset_seq = 0
        self.doc_root = doc_root
        self.raster_slots = 0
        self.sign_slots = 0

    def run(self):
        body = self.doc_root.find(W + 'body')
        paras = list(body.iter(W + 'p'))
        texts = [para_text(p) for p in paras]
        for i, p in enumerate(paras):
            self._paragraph(p, texts, i)
        return self.rows

    # --- строки -----------------------------------------------------------

    def _addr(self):
        """Адрес очередного абзаца внутри текущего члана (или без адреса)."""
        if self.chlan is None:
            return {'chapter': self.chapter, 'paragraph': None, 'chlan': None}
        self.par_no += 1
        return {'chapter': self.chapter, 'paragraph': str(self.par_no),
                'chlan': self.chlan}

    def _emit(self, sr, images=None, addr=None, is_title=False, ru=None):
        row = {
            'chapter': None, 'paragraph': None, 'chlan': None,
            'sr': sr, 'ru': ru, 'isTitle': is_title,
        }
        if addr:
            row.update(addr)
        if images:
            row['images'] = images
        self.rows.append(row)

    def _centered(self, p):
        jc = p.find(W + 'pPr/' + W + 'jc')
        return jc is not None and jc.get(W + 'val') == 'center'

    def _paragraph(self, p, texts, i):
        text = texts[i]
        drawings = list(p.iter(W + 'drawing'))
        if drawings:
            self._images(drawings, texts, i)
            return
        if not text or text in SKIP_LINES:
            return

        if text == 'ПРАВИЛНИК' or text == 'о саобраћајној сигнализацији':
            self._emit(f'**{text}**', is_title=True)
            return

        if APPENDIX_RE.match(text):
            self.appendix = True
            self.chapter = None
            self.chlan = None
            self.par_no = 0
            self._emit(f'### {md_escape(text)}')
            return

        if not self.appendix:
            m = CHAPTER_RE.match(text)
            if m and self._centered(p) and text == text.upper():
                self.chapter = m.group(1)
                self.chlan = None
                self.par_no = 0
                self._emit(text, addr={'chapter': self.chapter})
                return

            m = CHLAN_RE.match(text)
            if m:
                self.chlan = m.group(1)
                self.par_no = 0
                self._emit(f'Члан {self.chlan}.',
                           addr={'chapter': self.chapter,
                                 'chlan': self.chlan, 'paragraph': '0'})
                return

        if self._centered(p) and not text.endswith((';', ':', '.', ',')):
            # Подзаголовок раздела («Саобраћајни пројекат», «1.1. Знакови
            # опасности») — в этом docx они отличаются только выключкой.
            self._emit(f'### {md_escape(text.rstrip("*"))}')
            return

        self._emit(md_escape(text), addr=self._addr())

    # --- изображения ------------------------------------------------------

    def _preceding_codes(self, texts, i):
        """Коды знаков из ближайшего текстового абзаца выше строки картинок.

        Пункт перечисляет нарисованные знаки в скобках; один и тот же код
        повторяется в пункте по нескольку раз («(IV-10) паркирање …»), поэтому
        порядок первых вхождений и есть порядок картинок.
        """
        j = i - 1
        while j >= 0 and (not texts[j] or texts[j] in SKIP_LINES):
            j -= 1
        if j < 0:
            return []
        codes = CODE_PAREN_RE.findall(texts[j]) or CODE_RE.findall(texts[j])
        return list(dict.fromkeys(codes))

    def _extent(self, drawing):
        extent = drawing.find('.//' + WP + 'extent')
        if extent is None:
            return None, None
        w = round(int(extent.get('cx') or 0) / EMU_PER_PX, 1)
        h = round(int(extent.get('cy') or 0) / EMU_PER_PX, 1)
        if not w or not h or (w == BROKEN_EXTENT and h == BROKEN_EXTENT):
            return None, None
        return w, h

    def _images(self, drawings, texts, i):
        codes = self._preceding_codes(texts, i)
        official = [self.signs.resolve(c) for c in codes] if codes else []
        if official and all(official):
            # Все знаки пункта есть в assets/signs — рисунок docx не нужен:
            # ставим официальные SVG и подпись с кодами под ними.
            w, h = self._extent(drawings[0])
            unit_w = round(w / len(codes), 1) if w else DEFAULT_SIGN_W
            unit_h = h or DEFAULT_SIGN_H
            images = [{'src': src, 'w': unit_w, 'h': unit_h}
                      for src in official]
            self.sign_slots += 1
            self._emit('', images=images, addr=self._addr())
            # Подпись — одни коды, перевода не требует: ru = sr сразу, иначе
            # новая строка ждала бы прогона tool/pravilnik_ru.
            caption = f'**{" ".join(codes)}**'
            self._emit(caption, addr=self._addr(), ru=caption)
            return

        images = []
        for drawing in drawings:
            blip = drawing.find('.//' + A + 'blip')
            if blip is None:
                continue
            rid = blip.get(R + 'embed') or blip.get(R + 'link')
            if rid not in self.media:
                continue
            data, ext = self.media[rid]
            img = {'src': f'assets/pravilnik/{self._store(data, ext)}'}
            w, h = self._extent(drawing)
            img['w'] = w or DEFAULT_SIGN_W
            img['h'] = h or DEFAULT_SIGN_H
            images.append(img)
        if not images:
            return
        self.raster_slots += 1
        self._emit('', images=images, addr=self._addr())

    def _store(self, data, ext):
        digest = hashlib.sha1(data).hexdigest()
        if digest in self.assets:
            return self.assets[digest]
        self.asset_seq += 1
        name = f'img_{self.asset_seq:03d}.{ext}'
        with open(os.path.join(OUT_DIR, name), 'wb') as f:
            f.write(data)
        self.assets[digest] = name
        return name


def media_files(zf):
    """rel id → (данные, расширение). Картинки лежат в /media/*.bmp, но на
    деле это JPEG и PNG — расширение берём из сигнатуры файла."""
    rels = ET.fromstring(zf.read('word/_rels/document.xml.rels'))
    names = set(zf.namelist())
    media = {}
    for rel in rels:
        target = rel.get('Target') or ''
        path = target.lstrip('/')
        if not path.startswith('media/'):
            path = 'word/' + target
        if path not in names:
            continue
        data = zf.read(path)
        ext = 'png' if data[:4] == b'\x89PNG' else 'jpg'
        media[rel.get('Id')] = (data, ext)
    return media


def main():
    if not os.path.exists(DOCX):
        sys.exit(f'нет исходника: {DOCX}')
    zf = zipfile.ZipFile(DOCX)
    doc_root = ET.fromstring(zf.read('word/document.xml'))

    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR)

    parser = Parser(doc_root, media_files(zf), SignFiles())
    rows = parser.run()

    # Файлы, оставшиеся без ссылок (одинаковые рисунки слиты по хэшу).
    referenced = {img['src'] for r in rows for img in r.get('images', [])}
    for name in os.listdir(OUT_DIR):
        if f'assets/pravilnik/{name}' not in referenced:
            os.remove(os.path.join(OUT_DIR, name))

    # Русский перевод живёт только в собранном JSON (собран
    # tool/pravilnik_ru/merge_ru.py) — переносим его на новые строки по
    # сербскому тексту, чтобы пересборка из docx его не стирала.
    if os.path.exists(OUT_JSON):
        with open(OUT_JSON, encoding='utf-8') as f:
            old = {r['sr']: r.get('ru') for r in json.load(f)}
        kept = 0
        for r in rows:
            ru = old.get(r['sr'])
            if ru is not None:
                r['ru'] = ru
                kept += 1
        print(f'перенесено переводов: {kept} из {len(rows)}')

    tmp = tempfile.NamedTemporaryFile(
        'w', dir=os.path.dirname(OUT_JSON), delete=False, encoding='utf-8')
    with tmp:
        json.dump(rows, tmp, ensure_ascii=False, indent=1)
        tmp.write('\n')
    os.replace(tmp.name, OUT_JSON)

    chlans = {r['chlan'] for r in rows if r['chlan']}
    print(f'строк: {len(rows)}, членов: {len(chlans)}')
    print(f'рядов знаков из assets/signs: {parser.sign_slots}, '
          f'растровых рисунков docx: {parser.raster_slots} '
          f'({len(parser.assets)} файлов)')


if __name__ == '__main__':
    main()
