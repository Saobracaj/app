// Разовый инструмент задачи 1203867458890003: для каждого знака I–IV,
// оставшегося в правилнике извлечённым из docx рисунком, ищет ближайшие
// официальные SVG из assets/signs/ и рисует контактные листы
// build/match_signs_sheet_N.png (строка: docx-рисунок, затем топ-3 кандидата).
//
//   flutter test tool/match_unreplaced_signs_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const double _side = 96;
const _perSheet = 20;

final _captionRe =
    RegExp(r'^\*\*(?:[IVX]{1,3}\s*-\s*\d+(?:\.\d+)*\s*)+\*\*$');
final _codeRe = RegExp(r'[IVX]{1,3}\s*-\s*\d+(?:\.\d+)*');

List<String> _captionCodes(String? sr) {
  final text = (sr ?? '').trim();
  if (!_captionRe.hasMatch(text)) return const [];
  return _codeRe
      .allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'\s'), ''))
      .toList();
}

Future<ui.Picture?> _picture(String path) async {
  if (path.endsWith('.svg')) {
    final info = await vg.loadPicture(
      SvgStringLoader(await File(path).readAsString()),
      null,
    );
    return info.picture;
  }
  final codec =
      await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImage(frame.image, Offset.zero, Paint());
  return recorder.endRecording();
}

Future<Size> _size(String path) async {
  if (path.endsWith('.svg')) {
    final info = await vg.loadPicture(
      SvgStringLoader(await File(path).readAsString()),
      null,
    );
    return info.size;
  }
  final codec =
      await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  return Size(
      frame.image.width.toDouble(), frame.image.height.toDouble());
}

Future<List<int>> _raster(String path) async {
  final picture = await _picture(path);
  final source = await _size(path);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _side, _side),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final scale = (_side / source.width < _side / source.height)
      ? _side / source.width
      : _side / source.height;
  canvas.translate(
    (_side - source.width * scale) / 2,
    (_side - source.height * scale) / 2,
  );
  canvas.scale(scale);
  canvas.drawPicture(picture!);
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

Future<void> _draw(Canvas canvas, String path, Rect target) async {
  final picture = await _picture(path);
  final source = await _size(path);
  canvas.save();
  final scale = (target.width / source.width < target.height / source.height)
      ? target.width / source.width
      : target.height / source.height;
  canvas.translate(
    target.center.dx - source.width * scale / 2,
    target.center.dy - source.height * scale / 2,
  );
  canvas.scale(scale);
  canvas.drawPicture(picture!);
  canvas.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('match', () async {
    final rows = (json.decode(
            await File('assets/parsed_pravilnik.json').readAsString())
        as List)
        .cast<Map<String, dynamic>>();
    // Незаменённые пары «код I–IV → docx-файл», как их собирает dedupe_signs.
    final pairs = <MapEntry<String, String>>[];
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final imgs = (rows[i]['images'] as List?)
          ?.map((e) => (e as Map)['src'] as String)
          .toList();
      if (imgs == null || imgs.isEmpty) continue;
      final codes = <String>[];
      var j = i + 1;
      while (j < rows.length && codes.length < imgs.length) {
        final rowCodes = _captionCodes(rows[j]['sr'] as String?);
        if (rowCodes.isEmpty) break;
        codes.addAll(rowCodes);
        j++;
      }
      if (codes.length != imgs.length) continue;
      for (var k = 0; k < codes.length; k++) {
        if (!RegExp(r'^I{1,3}V?-').hasMatch(codes[k])) continue;
        if (!imgs[k].startsWith('assets/pravilnik/')) continue;
        if (!seen.add(imgs[k])) continue;
        pairs.add(MapEntry(codes[k], imgs[k]));
      }
    }

    final officialRasters = <String, List<int>>{};
    for (final f in Directory('assets/signs').listSync()) {
      final path = f.path;
      if (!path.endsWith('.svg')) continue;
      officialRasters[path] = await _raster(path);
    }

    final lines = <String>[];
    final sheetRows = <List<String>>[]; // [docx, top1, top2, top3]
    for (final pair in pairs) {
      final docxRaster = await _raster(pair.value);
      final scored = officialRasters.entries
          .map((e) => MapEntry(e.key, _difference(docxRaster, e.value)))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final top = scored.take(3).toList();
      String short(String p) =>
          p.replaceAll('assets/signs/', '').replaceAll('.svg', '');
      lines.add('${pair.key}\t${pair.value.split('/').last}\t'
          '${top.map((e) => '${short(e.key)}=${e.value.toStringAsFixed(3)}').join('\t')}');
      sheetRows.add([pair.value, for (final e in top) e.key]);
    }
    File('build/match_signs.txt').writeAsStringSync(lines.join('\n'));

    for (var sheet = 0; sheet * _perSheet < sheetRows.length; sheet++) {
      final chunk = sheetRows.skip(sheet * _perSheet).take(_perSheet).toList();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final height = _side * chunk.length;
      const width = _side * 5;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      for (var r = 0; r < chunk.length; r++) {
        final y = r * _side;
        for (var c = 0; c < chunk[r].length; c++) {
          // Колонка с зазором между docx (c=0) и кандидатами.
          final x = c == 0 ? 0.0 : _side * (c + 1);
          await _draw(canvas, chunk[r][c],
              Rect.fromLTWH(x + 6, y + 6, _side - 12, _side - 12));
          canvas.drawRect(
            Rect.fromLTWH(x, y, _side, _side),
            Paint()
              ..color = const Color(0xFF999999)
              ..style = PaintingStyle.stroke,
          );
        }
        final label = TextPainter(
          text: TextSpan(
            text: '${sheet * _perSheet + r}',
            style: const TextStyle(color: Color(0xFF000000), fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(_side + 8, y + 8));
      }
      final image = await recorder.endRecording().toImage(
            width.toInt(),
            height.toInt(),
          );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/match_signs_sheet_$sheet.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    }
    // ignore: avoid_print
    print('пар: ${pairs.length}, листов: '
        '${(sheetRows.length / _perSheet).ceil()}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
