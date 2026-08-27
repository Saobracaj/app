import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_markdown.dart';
import 'package:saobracaj/test/animations/road_sign.dart';

/// Конспекты вставляют официальные SVG знаков маркером `![…](anim/sign-<номер>)`
/// — в том числе внутри ячеек markdown-таблиц и в пунктах списков. Тест ловит
/// поломку этого пути: если flutter_markdown перестанет прогонять картинки
/// таблиц/списков через sizedImageBuilder или getAnimation перестанет понимать
/// префикс sign-, знаки молча пропадут из конспекта.
void main() {
  testWidgets('маркеры anim/sign-* рендерятся знаками в таблице и списке',
      (tester) async {
    const text = '''
| Знак | Значение |
|---|---|
| ![I-1](anim/sign-i-1) ![I-1.1](anim/sign-i-1.1) | *опасна кривина* |
| ![II-2](anim/sign-ii-2) | *обавезно заустављање* |

- ![II-30](anim/sign-ii-30-40) число в круге = *ограничење брзине*

![III-68](anim/sign-iii-68)
''';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: KonspektMarkdown(text: text))),
    ));
    expect(find.byType(RoadSignSvg), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });
}
