// Кому из знаков правилника 2010 года соответствует файл, который по имени
// в документе не нашёлся (образец 2017 года или переномерованный знак).
//
// Каждый такой файл сличается со всеми рисунками документа, оставшимися без
// официального SVG; печатается лучшая пара и рисуется контактный лист
// build/sign_gaps_sheet.png — принимать пару или нет, решают глазами.
//
//   python3 tool/parse_pravilnik.py --audit
//   flutter test tool/audit_signs_gaps_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const double _side = 96;

Future<List<int>> _raster(String path) async {
  final info = await vg.loadPicture(
    SvgStringLoader(await File(path).readAsString()),
    null,
  );
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

double _difference(List<int> a, List<int> b) {
  var sum = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      sum += (a[i + c] - b[i + c]).abs();
    }
  }
  return sum / (a.length / 4 * 3 * 255);
}

Future<void> _draw(Canvas canvas, List<int> _, String path, Rect target) async {
  final info = await vg.loadPicture(
    SvgStringLoader(await File(path).readAsString()),
    null,
  );
  canvas.save();
  final source = info.size;
  final scale =
      (target.width / source.width < target.height / source.height)
      ? target.width / source.width
      : target.height / source.height;
  canvas.translate(
    target.center.dx - source.width * scale / 2,
    target.center.dy - source.height * scale / 2,
  );
  canvas.scale(scale);
  canvas.drawPicture(info.picture);
  canvas.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('gaps', () async {
    final gaps =
        json.decode(await File('build/sign_gaps.json').readAsString())
            as Map<String, dynamic>;
    final targets = (gaps['undescribed'] as List).cast<String>();
    final docx = (gaps['docx'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
    final docxRasters = <String, List<int>>{};
    for (final entry in docx.entries) {
      docxRasters[entry.key] = await _raster(entry.value);
    }
    final best = <String, MapEntry<String, double>>{};
    for (final sign in targets) {
      final path = 'assets/signs/$sign.svg';
      if (!File(path).existsSync()) continue;
      final raster = await _raster(path);
      String? code;
      var score = 1.0;
      for (final entry in docxRasters.entries) {
        final diff = _difference(raster, entry.value);
        if (diff < score) {
          score = diff;
          code = entry.key;
        }
      }
      if (code != null) best[sign] = MapEntry(code, score);
    }
    final sorted = best.entries.toList()
      ..sort((a, b) => a.value.value.compareTo(b.value.value));
    final rows = sorted.length;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const perRow = 4;
    final height = _side * (rows / perRow).ceil();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _side * 2 * perRow, height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final x = (i % perRow) * _side * 2;
      final y = (i ~/ perRow) * _side;
      await _draw(canvas, const [], 'assets/signs/${e.key}.svg',
          Rect.fromLTWH(x + 4, y + 4, _side - 8, _side - 8));
      await _draw(canvas, const [], docx[e.value.key]!,
          Rect.fromLTWH(x + _side + 4, y + 4, _side - 8, _side - 8));
      canvas.drawRect(
        Rect.fromLTWH(x, y, _side * 2, _side),
        Paint()
          ..color = const Color(0xFF999999)
          ..style = PaintingStyle.stroke,
      );
      // ignore: avoid_print
      print('${i ~/ perRow},${i % perRow}: ${e.key} ~ ${e.value.key} '
          '(${e.value.value.toStringAsFixed(3)})');
    }
    final image = await recorder.endRecording().toImage(
      (_side * 2 * perRow).toInt(),
      height.toInt(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/sign_gaps_sheet.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}
