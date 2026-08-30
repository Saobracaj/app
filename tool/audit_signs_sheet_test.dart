// Контактный лист к tool/audit_signs_test.dart: пары «рисунок docx | знак из
// assets/signs/» в порядке убывания расхождения — глазами по картинке видно,
// подменён ли знак чужим.
//
//   flutter test tool/audit_signs_sheet_test.dart   → build/sign_audit_sheet.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const double _cell = 96;
const int _pairsPerRow = 4;
const int _limit = 32;

Future<void> _draw(Canvas canvas, String path, Rect target) async {
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
  test('sheet', () async {
    final lines = (await File('build/sign_audit_report.txt').readAsLines())
        .take(_limit)
        .toList();
    final rows = (lines.length / _pairsPerRow).ceil();
    final width = _cell * 2 * _pairsPerRow;
    final height = _cell * rows;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    for (var i = 0; i < lines.length; i++) {
      final parts = lines[i].trim().split(RegExp(r'\s+'));
      final docx = parts[1];
      final official = parts[3];
      final x = (i % _pairsPerRow) * _cell * 2;
      final y = (i ~/ _pairsPerRow) * _cell;
      await _draw(canvas, docx, Rect.fromLTWH(x + 4, y + 4, _cell - 8, _cell - 8));
      await _draw(
        canvas,
        official,
        Rect.fromLTWH(x + _cell + 4, y + 4, _cell - 8, _cell - 8),
      );
      canvas.drawRect(
        Rect.fromLTWH(x, y, _cell * 2, _cell),
        Paint()
          ..color = const Color(0xFF999999)
          ..style = PaintingStyle.stroke,
      );
      // ignore: avoid_print
      print('${i ~/ _pairsPerRow},${i % _pairsPerRow}: ${lines[i].trim()}');
    }
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'build/sign_audit_sheet.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
