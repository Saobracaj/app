#!/usr/bin/env python3
"""Рисует iii-23.svg («назив насељеног места») и iii-23.1.svg («завршетак
насељеног места») из официального вектора «Serbian road sign III-23.svg» с
Викисклада (копия — tool/data/serbian_road_sign_iii-23.svg).

На Викискладе оба знака только синие (для аутопута/мотопута), а в правилнику
2017 года рисунки III-23 и III-23.1 жёлтые с чёрной надписью: цвет основы
зависит от категории пута (чл. 50), и документ показывает вариант для
обычных путева. Чтобы вектор не спорил с текстом рядом, знак перекрашивается
в жёлтый (тот же #fdfa00, что у iii-3 «пут са првенством пролаза»), надпись и
рамка — в чёрный из iii-24.1, а у III-23.1 добавляется красная (#cc0000)
диагональ — как у iii-24.1 «завршетак насеља». Надпись в исходнике уже
переведена в контуры, поэтому flutter_svg её рисует; служебные части
Inkscape (namedview, metadata, foreignObject) выбрасываются.

Запуск из корня app/:  python3 tool/gen_naselje_signs.py
"""

import os
import re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'tool', 'data', 'serbian_road_sign_iii-23.svg')
SIGNS = os.path.join(ROOT, 'assets', 'signs')

SVG_NS = 'http://www.w3.org/2000/svg'
YELLOW = '#fdfa00'
BLACK = '#201b16'
RED = '#cc0000'

# Свойства style, которые нужны для отрисовки; остальное — следы шрифта и
# Inkscape (font-*, -inkscape-*, paint-order, text-anchor…).
KEEP_STYLE = {'fill', 'fill-opacity', 'fill-rule', 'opacity', 'stroke'}

RECOLOUR = {'#1060a9': YELLOW, '#ffffff': BLACK}


def _clean_style(style):
    out = []
    for item in style.split(';'):
        if ':' not in item:
            continue
        key, value = (s.strip() for s in item.split(':', 1))
        if key not in KEEP_STYLE:
            continue
        if key == 'fill':
            value = RECOLOUR.get(value.lower(), value)
        out.append(f'{key}:{value}')
    return ';'.join(out)


def _local(tag):
    return tag.split('}', 1)[1] if '}' in tag else tag


def _strip(elem):
    """Убирает служебные узлы и атрибуты чужих пространств имён."""
    for child in list(elem):
        if _local(child.tag) in ('namedview', 'metadata', 'defs', 'foreignObject'):
            elem.remove(child)
            continue
        _strip(child)
    for key in list(elem.attrib):
        if key.startswith('{'):
            del elem.attrib[key]
    if 'style' in elem.attrib:
        style = _clean_style(elem.attrib['style'])
        if style:
            elem.attrib['style'] = style
        else:
            del elem.attrib['style']


def _stripe(root):
    """Красная диагональ «завршетка»: из левого нижнего угла рамки в правый
    верхний, как на рисунке правилника и у iii-24.1."""
    width = float(root.attrib['viewBox'].split()[2])
    height = float(root.attrib['viewBox'].split()[3])
    margin = 7.0
    path = ET.SubElement(root, f'{{{SVG_NS}}}path')
    path.attrib['id'] = 'zavrsetak'
    path.attrib['d'] = (
        f'M {margin:.2f},{height - margin:.2f} '
        f'L {width - margin:.2f},{margin:.2f}'
    )
    path.attrib['style'] = (
        f'fill:none;stroke:{RED};stroke-width:12;stroke-linecap:butt'
    )


def _render(crossed):
    ET.register_namespace('', SVG_NS)
    tree = ET.parse(SOURCE)
    root = tree.getroot()
    _strip(root)
    for key in ('width', 'height'):
        root.attrib.pop(key, None)
    if crossed:
        _stripe(root)
    text = ET.tostring(root, encoding='unicode')
    # ElementTree пишет пространство имён на каждом узле только для не-SVG
    # тегов; лишних тут нет, но пустые строки после удаления узлов остаются.
    text = re.sub(r'\n\s*\n', '\n', text)
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + text + '\n'


def main():
    for name, crossed in (('iii-23', False), ('iii-23.1', True)):
        path = os.path.join(SIGNS, f'{name}.svg')
        with open(path, 'w', encoding='utf-8') as f:
            f.write(_render(crossed))
        print(f'{name}.svg: {os.path.getsize(path)} байт')


if __name__ == '__main__':
    main()
