// Сверка привязки «рисунок из docx правилника ↔ официальный SVG знака».
//
// Дедупликация в tool/parse_pravilnik.py подменяет извлечённые из docx знаки
// файлами assets/signs/, опираясь на подписи документа. Нумерация файлов
// (Wikimedia Commons, правилник 2017) местами расходится с нумерацией этого
// документа (2010), поэтому каждую пару надо сличать не по имени, а глазами —
// или, как здесь, попиксельно: оба SVG растеризуются в квадрат и сравнивается
// средняя разница цвета. Расхождение выше порога значит, что знак подменён
// чужим и описание в просмотрщике будет не от того знака.
//
// Запуск (после `python3 tool/parse_pravilnik.py --audit`):
//   flutter test tool/audit_signs_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const double _side = 96;

Future<List<int>> _raster(String path) async {
  final svg = await File(path).readAsString();
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _side, _side),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final source = info.size;
  final scale = (_side / source.width < _side / source.height)
      ? _side / source.width
      : _side / source.height;
  canvas.translate(
    (_side - source.width * scale) / 2,
    (_side - source.height * scale) / 2,
  );
  canvas.scale(scale);
  canvas.drawPicture(info.picture);
  final image = await recorder.endRecording().toImage(
    _side.toInt(),
    _side.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List().toList();
}

/// Средняя разница цвета двух растров, 0..1.
double _difference(List<int> a, List<int> b) {
  var sum = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      sum += (a[i + c] - b[i + c]).abs();
    }
  }
  return sum / (a.length / 4 * 3 * 255);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('sign mapping', () async {
    final mapping =
        json.decode(await File('build/sign_audit.json').readAsString())
            as Map<String, dynamic>;
    final scores = <String, double>{};
    for (final entry in mapping.entries) {
      final docx = entry.key;
      final official = entry.value as String;
      if (!docx.endsWith('.svg')) continue;
      try {
        final diff = _difference(await _raster(docx), await _raster(official));
        scores['$docx -> $official'] = diff;
      } catch (e) {
        // ignore: avoid_print
        print('ошибка на $docx -> $official: $e');
        scores['$docx -> $official'] = -1;
      }
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final report = sorted
        .map((e) => '${e.value.toStringAsFixed(4)}  ${e.key}')
        .join('\n');
    File('build/sign_audit_report.txt').writeAsStringSync(report);
    // ignore: avoid_print
    print(report);
  });
}
