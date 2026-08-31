#!/usr/bin/env python3
"""Рисует SVG знаков, у которых нет официального вектора ни на Commons, ни в
docx правилника (там они растровые): III-90 «одмориште», III-90.1 «излазак на
одмориште», III-203.1 «престројавање возила (кружни ток)» и текстовую
допунску таблу к паркиралишту («Временски ограничено на 1 сат» — как на
картинке экзаменационного вопроса №9208; в правилнике 2017 года это IV-5,
поэтому файл называется iv-5-parkiranje и описание находит по базовому IV-5).

Компоновка повторяет рисунки правилника; надписи переводятся в контуры
(flutter_svg не рендерит <text>), пиктограммы бензоколонки и чашки берутся из
официальных iii-38 / iii-41, остальные (корзина, грузовик, wi-fi, стрелки)
нарисованы примитивами.

Зависимости: fontTools (`python3 -m venv /tmp/venv && /tmp/venv/bin/pip
install fonttools`) и системный Arial Bold (macOS). Запуск из корня app/:

    /tmp/venv/bin/python tool/gen_konspekt_signs.py
"""

import math
import os
import re

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIGNS = os.path.join(ROOT, 'assets', 'signs')
FONT = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'

BLUE = '#0000cc'  # синий информационных знаков в официальных SVG (III-38…)
BLUE_2010 = '#0067ac'  # синий рисунков правилника 2010 (iii-203 оттуда)

_font = TTFont(FONT)
_cmap = _font.getBestCmap()
_glyphs = _font.getGlyphSet()
_upem = _font['head'].unitsPerEm
_hmtx = _font['hmtx']


def _num(v):
    return f'{v:.1f}'.rstrip('0').rstrip('.')


def text_width(text, size):
    return sum(_hmtx[_cmap[ord(c)]][0] for c in text) * size / _upem


def text_path(text, size, x, y, fill, anchor='middle'):
    """Надпись контурами: baseline в (x, y), anchor — start | middle."""
    w = text_width(text, size)
    pen_x = x - w / 2 if anchor == 'middle' else x
    pen = SVGPathPen(_glyphs, ntos=_num)
    s = size / _upem
    for c in text:
        name = _cmap[ord(c)]
        _glyphs[name].draw(TransformPen(pen, (s, 0, 0, -s, pen_x, y)))
        pen_x += _hmtx[name][0] * s
    return f'<path fill="{fill}" d="{pen.getCommands()}"/>'


def fit_size(text, max_width, size):
    w = text_width(text, size)
    return size if w <= max_width else size * max_width / w


# --- пиктограммы из официальных SVG ------------------------------------------

# У знаков III-3x…III-5x с Commons одна и та же геометрия: белая вставка
# (path5732) в координатах viewBox занимает этот прямоугольник, а символ
# нарисован после неё в системе координат слоя layer1-3.
INSET = (27.032, 25.763, 81.368, 101.675)
LAYER = ('translate(88.823173,-266.61216)', 'translate(3356.3256,-598.33825)')


def official_symbol(name, x, y, h):
    """Символ знака assets/signs/<name>.svg, вписанный в бокс высоты h с
    верхним левым углом (x, y) (ширина = h * 0.8, как у вставки)."""
    with open(os.path.join(SIGNS, name + '.svg'), encoding='utf-8') as f:
        svg = f.read()
    inset = re.search(r'<path[^>]*id="path5732"[^>]*/>', svg)
    inner = svg[inset.end():]
    inner = inner[:inner.rfind('</g>')]
    inner = inner[:inner.rfind('</g>')]
    inner = re.sub(r'\s+id="[^"]*"', '', inner)
    s = h / INSET[3]
    tx = x - INSET[0] * s
    ty = y - INSET[1] * s
    return (f'<g transform="translate({_num(tx)},{_num(ty)}) scale({_num(s)})">'
            f'<g transform="{LAYER[0]}"><g transform="{LAYER[1]}">{inner}'
            '</g></g></g>')


# --- пиктограммы примитивами (в боксе 48×48 с верхним левым углом x, y) ------

def cart(x, y):
    g = f'<g transform="translate({x},{y})" fill="#000">'
    g += '<path d="M2 4 h7 l3 8 h33 l-5 16 h-25 l1 4 h26 v4 h-30 l-2 -8 -6 -20 h-2 z"/>'
    g += '<circle cx="18" cy="42" r="3.5"/><circle cx="36" cy="42" r="3.5"/>'
    # товары в корзине
    g += '<path d="M17 10 v-6 h6 v6 z M25 10 v-8 h5 v8 z M32 10 v-5 h6 v5 z"/>'
    return g + '</g>'


def truck(x, y):
    g = f'<g transform="translate({x},{y})" fill="#000">'
    g += '<path d="M2 12 h28 v22 h-28 z M31 18 h9 l6 8 v8 h-15 z"/>'
    g += '<path d="M2 34 h44 v3 h-44 z"/>'
    g += '<circle cx="11" cy="38" r="4.5"/><circle cx="37" cy="38" r="4.5"/>'
    g += '<path d="M34 20 h5 l4 5 h-9 z" fill="#fff"/>'
    return g + '</g>'


def wifi(x, y):
    g = f'<g transform="translate({x},{y})" fill="none" stroke="#000" stroke-width="4">'
    g += '<path d="M6 20 a25 25 0 0 1 36 0"/>'
    g += '<path d="M13 27 a15 15 0 0 1 22 0"/>'
    g += '<path d="M19 33 a6.5 6.5 0 0 1 10 0"/>'
    g += '</g>'
    g += f'<g transform="translate({x},{y})" fill="#000"><path d="M20 38 h8 l-4 8 z"/></g>'
    return g


def arrow_up_right(cx, cy, size, fill):
    """Стрелка «вверх-направо» с центром в (cx, cy)."""
    s = size / 100
    body = 'M-38 26 l48 -48 l-14 -14 h48 v48 l-14 -14 l-48 48 z'
    return (f'<path transform="translate({cx},{cy}) scale({_num(s)})" '
            f'd="{body}" fill="{fill}"/>')


# --- знаки ----------------------------------------------------------------------

def odmoriste(exit_variant):
    W, H = 300, 400
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
           f'width="{W}" height="{H}">']
    out.append(f'<rect x="1.5" y="1.5" width="{W - 3}" height="{H - 3}" rx="12" '
               'fill="#fff" stroke="#000" stroke-width="1.5"/>')
    out.append(f'<rect x="10" y="10" width="{W - 20}" height="{H - 20}" rx="7" '
               f'fill="{BLUE}"/>')
    out.append(text_path('ОДМОРИШТЕ', 40, W / 2, 64, '#fff'))
    out.append(text_path('REST AREA', 36, W / 2, 106, '#fff'))
    # поле под название одморишта
    out.append('<rect x="30" y="124" width="240" height="56" rx="3" fill="none" '
               'stroke="#fff" stroke-width="1.5"/>')
    cells = [(36, 200), (118, 200), (200, 200), (36, 276), (118, 276), (200, 276)]
    for cx, cy in cells:
        out.append(f'<rect x="{cx}" y="{cy}" width="64" height="64" rx="3" fill="#fff"/>')
    # бензоколонка, корзина, P / чашка, грузовик, wi-fi
    out.append(official_symbol('iii-38', 36 + 12, 200 + 7, 50))
    out.append(cart(118 + 8, 200 + 8))
    out.append(text_path('P', 56, 200 + 32, 200 + 52, '#000'))
    out.append(official_symbol('iii-41', 36 + 12, 276 + 7, 50))
    out.append(truck(118 + 8, 276 + 8))
    out.append(wifi(200 + 8, 276 + 8))
    if exit_variant:
        out.append(arrow_up_right(W / 2, 368, 44, '#fff'))
    else:
        out.append(text_path('5 km', 36, W / 2, 382, '#fff'))
    out.append('</svg>')
    return '\n'.join(out)


def prestrojavanje_kruzni_tok():
    """III-203.1: две полосы, из каждой — заезд в кружни ток со съездом."""
    W = 300
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {W}" '
           f'width="{W}" height="{W}">']
    out.append(f'<rect x="0" y="0" width="{W}" height="{W}" fill="{BLUE_2010}"/>')
    out.append('<rect x="11" y="11" width="278" height="278" rx="20" fill="#fff"/>')
    out.append(f'<rect x="18" y="18" width="264" height="264" rx="14" fill="{BLUE_2010}"/>')
    # разделительная прерывистая линия
    out.append('<path d="M150 42 V258" stroke="#fff" stroke-width="6" '
               'stroke-dasharray="18 10" fill="none"/>')
    for x, side in ((95, -1), (205, 1)):
        # полоса: снизу до кольца и от кольца вверх к стрелке
        out.append(f'<path d="M{x} 258 V186 M{x} 148 V72" stroke="#fff" '
                   'stroke-width="9" fill="none"/>')
        out.append(f'<path d="M{x - 15} 78 L{x} 46 L{x + 15} 78 z" fill="#fff"/>')
        # кольцо
        out.append(f'<circle cx="{x}" cy="167" r="19" fill="none" stroke="#fff" '
                   'stroke-width="9"/>')
        # съезд с кольца в сторону
        ex = x + side * 19
        tip = x + side * 58
        out.append(f'<path d="M{ex} 167 H{x + side * 40}" stroke="#fff" '
                   'stroke-width="9" fill="none"/>')
        out.append(f'<path d="M{x + side * 38} 152 L{tip} 167 L{x + side * 38} 182 z" '
                   'fill="#fff"/>')
    out.append('</svg>')
    return '\n'.join(out)


def parking_time_plate():
    W, H = 300, 180
    lines = ['Временски', 'ограничено на', '1 сат']
    size = min(fit_size(line, 250, 38) for line in lines)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
           f'width="{W}" height="{H}">']
    out.append(f'<rect x="2" y="2" width="{W - 4}" height="{H - 4}" rx="8" '
               'fill="#fff" stroke="#000" stroke-width="4"/>')
    for i, line in enumerate(lines):
        out.append(text_path(line, size, W / 2, 62 + i * 46, '#000'))
    out.append('</svg>')
    return '\n'.join(out)


# --- надпись уклона на I-3 / I-4 ------------------------------------------------

# Официальные SVG «опасан успон» (I-3) и «опасна низбрдица» (I-4) с Викисклада
# рисуют только чёрный клин: величина уклона там переменная и в шаблон не
# вписана. В правилнике же на рисунке стоит «12 %» вдоль ската, и без числа
# знак читается как чужой — надпись дорисовывается сюда.
#
# Координаты сняты с самого файла: чёрный клин лежит в path8885, а все
# обёртки-<g> сводятся к переносу (325.3465, -102.24591) в системе viewBox.
NAGIB_TEXT = '12 %'
NAGIB_SLOPE = {
    # файл: (начало ската, конец ската) — по возрастанию x
    'i-3': ((153.0, 550.6), (493.6, 374.4)),   # успон: скат идёт вверх
    'i-4': ((255.98, 374.42), (596.6, 550.57)),  # низбрдица: скат идёт вниз
}
NAGIB_RE = re.compile(r'\n?  <g id="nagib"[^>]*>.*?</g>', re.S)


def nagib_group(name):
    """Группа с надписью уклона вдоль ската знака [name]."""
    (x1, y1), (x2, y2) = NAGIB_SLOPE[name]
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    angle = math.degrees(math.atan2(dy, dx))
    # Размер: надпись занимает чуть меньше половины ската — как на рисунке.
    size = fit_size(NAGIB_TEXT, length * 0.46, 1000)
    # Середина надписи — на верхней половине ската, сама она поднята над ним
    # по нормали (внешняя сторона клина — та, что выше ската).
    t = 0.46 if name == 'i-3' else 0.45
    cx, cy = x1 + dx * t, y1 + dy * t
    nx, ny = uy, -ux
    if ny > 0:
        nx, ny = -nx, -ny
    gap = size * 0.24
    bx, by = cx + nx * gap, cy + ny * gap
    return (f'  <g id="nagib" '
            f'transform="rotate({_num(angle)},{_num(bx)},{_num(by)})">'
            f'{text_path(NAGIB_TEXT, size, bx, by, "#000")}</g>')


def with_nagib(name):
    """Официальный SVG знака с дорисованной надписью уклона (идемпотентно)."""
    with open(os.path.join(SIGNS, name + '.svg'), encoding='utf-8') as f:
        svg = NAGIB_RE.sub('', f.read())
    return svg.replace('</svg>', nagib_group(name) + '\n</svg>')


def main():
    files = {
        'iii-90': odmoriste(exit_variant=False),
        'iii-90.1': odmoriste(exit_variant=True),
        'iii-203.1': prestrojavanje_kruzni_tok(),
        'iv-5-parkiranje': parking_time_plate(),
        # Знаки с Викисклада, которым дописывается величина уклона.
        'i-3': with_nagib('i-3'),
        'i-4': with_nagib('i-4'),
    }
    for name, svg in files.items():
        path = os.path.join(SIGNS, name + '.svg')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(svg.rstrip('\n') + '\n')
        print(f'{path}: {os.path.getsize(path)} байт')


if __name__ == '__main__':
    main()
