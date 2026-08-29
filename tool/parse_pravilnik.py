#!/usr/bin/env python3
"""Собирает assets/parsed_pravilnik.json и assets/pravilnik/* из docx правилника.

Источник — tool/data/pravilnik_o_saobracajnoj_signalizaciji.docx («Правилник о
саобраћајној сигнализацији», вложение задачи 1217968287062170). Знаки в нём
нарисованы векторно (DrawingML: группы фигур из custGeom-путей moveTo/lnTo),
поэтому каждая группа конвертируется в самостоятельный SVG; растровые вставки
внутри групп встраиваются в SVG как data-URI, а отдельные растровые рисунки
(фотографии, разметка) копируются как есть из word/media.

JSON повторяет схему assets/parsed_zakon.json (chapter/chlan/paragraph/sr/ru/
isTitle) и добавляет опциональное поле images — список ассетов, показываемых
под текстом строки. Адресация строк (chapter+chlan+paragraph) даёт те же
ссылки, что и в законе: /pravilnik?chapter=…&chlan=…&paragraph=…

Запуск из корня app/:  python3 tool/parse_pravilnik.py
"""

import base64
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
PIC = '{http://schemas.openxmlformats.org/drawingml/2006/picture}'
WPG = '{http://schemas.microsoft.com/office/word/2010/wordprocessingGroup}'
WPS = '{http://schemas.microsoft.com/office/word/2010/wordprocessingShape}'
R = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCX = os.path.join(ROOT, 'tool', 'data', 'pravilnik_o_saobracajnoj_signalizaciji.docx')
OUT_JSON = os.path.join(ROOT, 'assets', 'parsed_pravilnik.json')
OUT_DIR = os.path.join(ROOT, 'assets', 'pravilnik')

EMU_PER_PX = 9525  # 96 dpi
EMU_PER_PT = 12700

ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']

# Код знака/ознаке («I-1», «II-30.1», «III-84a», «IV-5»…) — такие строки в
# таблицах-подписях выделяются жирным, как и заголовки Heading4.
SIGN_CODE_RE = re.compile(r'^[IVX]+-[0-9]+(\.[0-9]+)*[а-шa-z]?$')


def emu(v):
    return int(v) if v is not None else 0


def fmt(v):
    """Число для SVG: без хвоста «.0», чтобы файлы были компактнее."""
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    if isinstance(v, float):
        return f'{v:.1f}'
    return str(v)


class Numbering:
    """Синтез номеров списков: в docx «1)», «2)»… не текст, а w:numPr."""

    def __init__(self, numbering_xml):
        self.counters = {}
        self.levels = {}  # (numId, ilvl) -> (lvlText, start)
        if numbering_xml is None:
            return
        root = ET.fromstring(numbering_xml)
        abstract = {}
        for an in root.iter(W + 'abstractNum'):
            aid = an.get(W + 'abstractNumId')
            for lvl in an.findall(W + 'lvl'):
                ilvl = lvl.get(W + 'ilvl')
                num_fmt = lvl.find(W + 'numFmt')
                txt = lvl.find(W + 'lvlText')
                start = lvl.find(W + 'start')
                abstract[(aid, ilvl)] = (
                    num_fmt.get(W + 'val') if num_fmt is not None else 'decimal',
                    txt.get(W + 'val') if txt is not None else '%1',
                    int(start.get(W + 'val')) if start is not None else 1,
                )
        for num in root.iter(W + 'num'):
            num_id = num.get(W + 'numId')
            aid = num.find(W + 'abstractNumId').get(W + 'val')
            for (a_id, ilvl), spec in abstract.items():
                if a_id == aid:
                    self.levels[(num_id, ilvl)] = spec

    def label(self, p):
        num_pr = p.find(W + 'pPr/' + W + 'numPr')
        if num_pr is None:
            return None
        num_id_el = num_pr.find(W + 'numId')
        ilvl_el = num_pr.find(W + 'ilvl')
        if num_id_el is None:
            return None
        num_id = num_id_el.get(W + 'val')
        ilvl = ilvl_el.get(W + 'val') if ilvl_el is not None else '0'
        spec = self.levels.get((num_id, ilvl))
        if spec is None:
            return None
        num_fmt, lvl_text, start = spec
        if num_fmt == 'bullet':
            return '–'
        key = (num_id, ilvl)
        self.counters[key] = self.counters.get(key, start - 1) + 1
        return lvl_text.replace('%1', str(self.counters[key])).replace(
            '%2', str(self.counters[key]))


class SvgBuilder:
    """DrawingML-группа → SVG. Координаты остаются в EMU (через viewBox)."""

    def __init__(self, media):
        self.media = media  # rel id -> (bytes, ext)

    def convert(self, drawing):
        """Возвращает (kind, payload): ('svg', str) | ('raster', rel_id) | None."""
        group = drawing.find('.//' + WPG + 'wgp')
        if group is not None:
            return 'svg', self._group_svg(group)
        wsp = drawing.find('.//' + WPS + 'wsp')
        if wsp is not None:
            return 'svg', self._single_shape_svg(wsp)
        pic = drawing.find('.//' + PIC + 'pic')
        if pic is not None:
            blip = pic.find('.//' + A + 'blip')
            if blip is not None:
                return 'raster', blip.get(R + 'embed')
        return None

    def _group_svg(self, group):
        xfrm = group.find(WPG + 'grpSpPr/' + A + 'xfrm')
        off = xfrm.find(A + 'off')
        ext = xfrm.find(A + 'ext')
        ch_off = xfrm.find(A + 'chOff')
        ch_ext = xfrm.find(A + 'chExt')
        # Без chOff/chExt детская система координат совпадает с ext.
        if ch_off is not None and ch_ext is not None:
            vb = (emu(ch_off.get('x')), emu(ch_off.get('y')),
                  emu(ch_ext.get('cx')), emu(ch_ext.get('cy')))
        else:
            vb = (0, 0, emu(ext.get('cx')), emu(ext.get('cy')))
        w_px = emu(ext.get('cx')) / EMU_PER_PX
        h_px = emu(ext.get('cy')) / EMU_PER_PX
        del off
        body = []
        for child in group:
            tag = child.tag
            if tag == WPS + 'wsp':
                body.append(self._shape(child))
            elif tag == PIC + 'pic':
                body.append(self._picture(child))
        return self._svg(vb, w_px, h_px, body)

    def _single_shape_svg(self, wsp):
        sp_pr = wsp.find(WPS + 'spPr')
        xfrm = sp_pr.find(A + 'xfrm')
        off = xfrm.find(A + 'off')
        ext = xfrm.find(A + 'ext')
        vb = (emu(off.get('x')), emu(off.get('y')),
              emu(ext.get('cx')), emu(ext.get('cy')))
        return self._svg(vb, emu(ext.get('cx')) / EMU_PER_PX,
                         emu(ext.get('cy')) / EMU_PER_PX, [self._shape(wsp)])

    def _svg(self, vb, w_px, h_px, body):
        # Рисунок без видимого содержимого (например, текстбокс с пустой
        # таблицей размеров) не стоит и файла.
        if not any(p for p in body if p):
            return None
        parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{fmt(round(w_px, 1))}" height="{fmt(round(h_px, 1))}" '
            f'viewBox="{vb[0]} {vb[1]} {vb[2]} {vb[3]}">'
        ]
        parts.extend(p for p in body if p)
        parts.append('</svg>')
        return '\n'.join(parts)

    def _shape(self, wsp):
        sp_pr = wsp.find(WPS + 'spPr')
        xfrm = sp_pr.find(A + 'xfrm')
        off = xfrm.find(A + 'off')
        ext = xfrm.find(A + 'ext')
        ox, oy = emu(off.get('x')), emu(off.get('y'))
        cx, cy = emu(ext.get('cx')), emu(ext.get('cy'))

        fill = self._fill_color(sp_pr)
        stroke, stroke_w = self._stroke(sp_pr)

        out = []
        cust = sp_pr.find(A + 'custGeom')
        if cust is not None:
            d_parts = []
            for path in cust.findall(A + 'pathLst/' + A + 'path'):
                pw = emu(path.get('w')) or cx
                ph = emu(path.get('h')) or cy
                sx = cx / pw if pw else 1
                sy = cy / ph if ph else 1
                for cmd in path:
                    tag = cmd.tag
                    if tag in (A + 'moveTo', A + 'lnTo'):
                        pt = cmd.find(A + 'pt')
                        x = ox + emu(pt.get('x')) * sx
                        y = oy + emu(pt.get('y')) * sy
                        letter = 'M' if tag == A + 'moveTo' else 'L'
                        d_parts.append(f'{letter}{fmt(round(x, 1))} {fmt(round(y, 1))}')
                    elif tag == A + 'close':
                        d_parts.append('Z')
            if d_parts:
                attrs = f'fill="{fill}" fill-rule="evenodd"'
                if stroke:
                    attrs += f' stroke="{stroke}" stroke-width="{stroke_w}"'
                out.append(f'<path d="{" ".join(d_parts)}" {attrs}/>')
        elif sp_pr.find(A + 'prstGeom') is not None:
            # В документе встречается только prst="rect" (плашки под текст).
            if fill != 'none' or stroke:
                attrs = f'fill="{fill}"'
                if stroke:
                    attrs += f' stroke="{stroke}" stroke-width="{stroke_w}"'
                out.append(f'<rect x="{ox}" y="{oy}" width="{cx}" height="{cy}" {attrs}/>')

        txbx = wsp.find(WPS + 'txbx')
        if txbx is not None:
            out.append(self._textbox(txbx, ox, oy, cx, cy))
        return '\n'.join(p for p in out if p)

    def _fill_color(self, sp_pr):
        solid = sp_pr.find(A + 'solidFill/' + A + 'srgbClr')
        if solid is not None:
            return '#' + solid.get('val')
        if sp_pr.find(A + 'noFill') is not None:
            return 'none'
        return 'none'

    def _stroke(self, sp_pr):
        ln = sp_pr.find(A + 'ln')
        if ln is None:
            return None, 0
        clr = ln.find(A + 'solidFill/' + A + 'srgbClr')
        if clr is None:
            return None, 0
        return '#' + clr.get('val'), emu(ln.get('w')) or EMU_PER_PX

    def _picture(self, pic):
        blip = pic.find('.//' + A + 'blip')
        xfrm = pic.find(PIC + 'spPr/' + A + 'xfrm')
        if blip is None or xfrm is None:
            return ''
        rid = blip.get(R + 'embed')
        if rid not in self.media:
            return ''
        data, ext = self.media[rid]
        mime = 'image/jpeg' if ext in ('jpg', 'jpeg') else 'image/png'
        off = xfrm.find(A + 'off')
        extent = xfrm.find(A + 'ext')
        b64 = base64.b64encode(data).decode('ascii')
        return (f'<image x="{emu(off.get("x"))}" y="{emu(off.get("y"))}" '
                f'width="{emu(extent.get("cx"))}" height="{emu(extent.get("cy"))}" '
                f'preserveAspectRatio="none" '
                f'xlink:href="data:{mime};base64,{b64}"/>')

    def _textbox(self, txbx, ox, oy, cx, cy):
        """Подписи на технических рисунках: строки текста сверху вниз."""
        out = []
        y = oy
        for p in txbx.iter(W + 'p'):
            runs = p.findall(W + 'r')
            text = ''.join(
                t.text or '' for r in runs for t in r.findall(W + 't'))
            if not text.strip():
                continue
            sz_el = p.find('.//' + W + 'sz')  # в полупунктах
            size_pt = (int(sz_el.get(W + 'val')) / 2) if sz_el is not None else 7
            size = size_pt * EMU_PER_PT
            color_el = p.find('.//' + W + 'color')
            color = '#' + color_el.get(W + 'val') if color_el is not None else '#000000'
            line_h = size * 1.25
            y += line_h
            out.append(
                f'<text x="{ox}" y="{fmt(round(y, 1))}" font-family="sans-serif" '
                f'font-size="{fmt(round(size, 1))}" fill="{color}">'
                f'{escape_xml(text)}</text>')
        return '\n'.join(out)


def escape_xml(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def para_text(p):
    """Текст абзаца без подписей внутри рисунков.

    w:t внутри w:drawing (надписи на техрисунках) и внутри w:pict (их
    VML-фолбэк — тот же текст второй раз) — не текст абзаца.
    """
    parts = []

    def walk(el):
        for ch in el:
            if ch.tag in (W + 'drawing', W + 'pict'):
                continue
            if ch.tag == W + 't':
                parts.append(ch.text or '')
            walk(ch)

    walk(p)
    return ''.join(parts)


class Parser:
    def __init__(self, doc_root, media, numbering):
        self.media = media
        self.numbering = numbering
        self.svg = SvgBuilder(media)
        self.rows = []
        self.chapter = None
        self.chapter_idx = 0
        self.chlan = None
        self.par_no = 0
        self.assets = {}  # content hash -> asset file name
        self.asset_seq = 0
        self.doc_root = doc_root

    def run(self):
        body = self.doc_root.find(W + 'body')
        for el in body:
            if el.tag == W + 'p':
                self._paragraph(el)
            elif el.tag == W + 'tbl':
                self._table(el)
        return self.rows

    # --- строки -----------------------------------------------------------

    def _addr(self):
        """Адрес очередного абзаца внутри текущего члана (или без адреса)."""
        if self.chlan is None:
            return {'chapter': self.chapter, 'paragraph': None, 'chlan': None}
        self.par_no += 1
        return {'chapter': self.chapter, 'paragraph': str(self.par_no),
                'chlan': self.chlan}

    def _emit(self, sr, images=None, addr=None, is_title=False):
        row = {
            'chapter': None, 'paragraph': None, 'chlan': None,
            'sr': sr, 'ru': None, 'isTitle': is_title,
        }
        if addr:
            row.update(addr)
        if images:
            row['images'] = images
        self.rows.append(row)

    def _paragraph(self, p, in_table=False):
        style_el = p.find(W + 'pPr/' + W + 'pStyle')
        style = style_el.get(W + 'val') if style_el is not None else None
        text = para_text(p).strip()
        images = self._images(p)

        if style == 'Title':
            self._emit(f'**{text}**', is_title=True)
            return
        if style == 'Heading1':
            self.chapter_idx += 1
            self.chapter = ROMAN[self.chapter_idx - 1]
            self.chlan = None
            self.par_no = 0
            self._emit(f'{self.chapter}. {text}',
                       addr={'chapter': self.chapter})
            return
        if style == 'Heading2':
            self._emit(f'### {text}')
            return
        # Заголовок члена: чаще стиль Heading3, но ~30 из них — абзацы без
        # стиля, поэтому распознаём по самому тексту «Члан N.».
        m = re.match(r'Члан\s+(\S+?)\.?$', text)
        if m and not images:
            self.chlan = m.group(1)
            self.par_no = 0
            self._emit(text, addr={'chapter': self.chapter,
                                   'chlan': self.chlan, 'paragraph': '0'})
            return
        if style == 'Heading3':
            # Heading3 используется и для подзаголовков разделов
            # («Знакови опасности»), не только для «Члан N.». У подзаголовка
            # «Постављање семафора» рисунки прямо в абзаце — им своя строка.
            self._emit(f'### {text}')
            if images:
                self._emit('', images=images, addr=self._addr())
            return
        if not text and not images:
            return

        label = self.numbering.label(p)
        if label:
            text = f'{label} {text}'
        if style == 'Heading4' or (in_table and SIGN_CODE_RE.match(text)):
            text = f'**{text}**'
        self._emit(text, images=images, addr=self._addr())

    def _table(self, tbl):
        for p in tbl.iter(W + 'p'):
            self._paragraph(p, in_table=True)

    # --- изображения ------------------------------------------------------

    def _images(self, p):
        images = []
        for drawing in p.iter(W + 'drawing'):
            res = self.svg.convert(drawing)
            if res is None:
                continue
            kind, payload = res
            if payload is None:
                continue
            if kind == 'svg':
                name = self._store(payload.encode('utf-8'), 'svg')
            else:
                if payload not in self.media:
                    continue
                data, ext = self.media[payload]
                name = self._store(data, ext)
            images.append(f'assets/pravilnik/{name}')
        return images

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


def main():
    if not os.path.exists(DOCX):
        sys.exit(f'нет исходника: {DOCX}')
    zf = zipfile.ZipFile(DOCX)
    doc_root = ET.fromstring(zf.read('word/document.xml'))

    rels_root = ET.fromstring(zf.read('word/_rels/document.xml.rels'))
    media = {}
    for rel in rels_root:
        target = rel.get('Target')
        if target and target.startswith('media/'):
            ext = target.rsplit('.', 1)[-1].lower()
            media[rel.get('Id')] = (zf.read('word/' + target), ext)

    numbering_xml = None
    if 'word/numbering.xml' in zf.namelist():
        numbering_xml = zf.read('word/numbering.xml')

    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR)

    parser = Parser(doc_root, media, Numbering(numbering_xml))
    rows = parser.run()

    tmp = tempfile.NamedTemporaryFile(
        'w', dir=os.path.dirname(OUT_JSON), delete=False, encoding='utf-8')
    with tmp:
        json.dump(rows, tmp, ensure_ascii=False, indent=1)
    os.replace(tmp.name, OUT_JSON)

    n_svg = sum(1 for v in parser.assets.values() if v.endswith('.svg'))
    n_ras = len(parser.assets) - n_svg
    print(f'строк: {len(rows)}, ассетов: {len(parser.assets)} '
          f'(svg: {n_svg}, растровых: {n_ras})')
    chlans = {r["chlan"] for r in rows if r["chlan"]}
    print(f'глав: {parser.chapter_idx}, членов: {len(chlans)}')


if __name__ == '__main__':
    main()
