import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/home/presentation/exam_trend_card.dart';

/// Раскладка подписей на графике симуляций (карточка «Симуляции экзамена»):
/// подпись последнего балла держится у своей точки, подпись «проходной N»
/// стоит у правого края пунктира и уходит к левому, когда последний балл
/// близок к проходному и подписи наложились бы друг на друга (SAOBR-510).
void main() {
  const size = Size(300, 96);
  const valueSize = Size(16, 14);
  const passSize = Size(80, 14);
  // y(points) по тем же полям, что у painter: 12 сверху, 6 снизу.
  double y(int points) => 12 + 78 * (1 - points / 100);

  Rect rectOf(Offset o, Size s) => o & s;

  test('последний балл далеко от проходного — подпись проходного справа', () {
    final labels = ExamTrendPainter.placeLabels(
      size: size,
      lastDot: Offset(size.width - 6, y(40)),
      passY: y(85),
      valueSize: valueSize,
      passSize: passSize,
    );
    expect(labels.pass.dx, size.width - passSize.width);
    expect(
      rectOf(labels.pass, passSize).overlaps(rectOf(labels.value, valueSize)),
      isFalse,
    );
    // Цифра над точкой.
    expect(labels.value.dy + valueSize.height, lessThan(y(40)));
  });

  test(
    'последний балл рядом с проходным — подпись проходного уходит влево',
    () {
      // Сценарий со скриншота: проходной 85, последняя попытка 80 баллов.
      final labels = ExamTrendPainter.placeLabels(
        size: size,
        lastDot: Offset(size.width - 6, y(80)),
        passY: y(85),
        valueSize: valueSize,
        passSize: passSize,
      );
      expect(labels.pass.dx, 0);
      expect(labels.pass.dy, y(85) - passSize.height - 2);
      expect(
        rectOf(labels.pass, passSize).overlaps(rectOf(labels.value, valueSize)),
        isFalse,
      );
    },
  );

  test('ровно проходной балл — подписи тоже не пересекаются', () {
    final labels = ExamTrendPainter.placeLabels(
      size: size,
      lastDot: Offset(size.width - 6, y(85)),
      passY: y(85),
      valueSize: valueSize,
      passSize: passSize,
    );
    expect(labels.pass.dx, 0);
    expect(
      rectOf(labels.pass, passSize).overlaps(rectOf(labels.value, valueSize)),
      isFalse,
    );
  });

  test('у верхнего края цифра опускается под точку и не вылезает за холст', () {
    final labels = ExamTrendPainter.placeLabels(
      size: size,
      lastDot: Offset(size.width - 6, y(100)),
      passY: y(85),
      valueSize: valueSize,
      passSize: passSize,
    );
    expect(labels.value.dy, y(100) + 8);
    expect(labels.value.dx + valueSize.width, lessThanOrEqualTo(size.width));
    expect(
      rectOf(labels.pass, passSize).overlaps(rectOf(labels.value, valueSize)),
      isFalse,
    );
  });
}
