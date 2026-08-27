import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Официальные SVG знаков (assets/signs/) рисуются иллюстрациями через
/// lib/test/animations/road_sign.dart. Тест ловит две поломки:
/// битый/неподдерживаемый flutter_svg'ом файл и знак, на который код
/// ссылается, а ассета нет (в приложении такой знак молча не нарисуется).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('каждый SVG из assets/signs парсится и не пуст', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final signAssets = manifest
        .listAssets()
        .where((key) => key.startsWith('assets/signs/'))
        .toList();
    expect(signAssets, isNotEmpty);

    for (final key in signAssets) {
      final info = await vg.loadPicture(SvgAssetLoader(key), null);
      expect(info.size.width, greaterThan(0), reason: key);
      expect(info.size.height, greaterThan(0), reason: key);
      info.picture.dispose();
    }
  });

  test('каждый знак, упомянутый в иллюстрациях, есть в assets/signs', () {
    // Ссылки на знаки в коде — строковые литералы вида 'II-30-blank',
    // 'III-2.1', 'I-35-t3' в вызовах paint()/RoadSignScope/RoadSignSvg.
    final pattern = RegExp("'((?:I|II|III|IV)-[0-9][0-9A-Za-z.\\-\$]*)'");
    final referenced = <String>{};
    for (final file in Directory('lib/test/animations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Без комментариев: в доках встречаются примеры вида `'II-2'`.
      final code = file
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final m in pattern.allMatches(code)) {
        var sign = m.group(1)!;
        // Интерполяция вида 'I-35-t${board.stripes}' проверяется по всем
        // существующим вариантам ниже; сам литерал пропускаем.
        if (sign.contains(r'$')) continue;
        referenced.add(sign.toLowerCase());
      }
    }
    expect(referenced, isNotEmpty);

    final available = Directory('assets/signs')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
        .toSet();
    for (final sign in referenced) {
      expect(available, contains(sign),
          reason: 'нет assets/signs/$sign.svg, на который ссылается код');
    }
  });
}
