import 'package:flutter/material.dart';
import 'package:saobracaj/theme/app_theme.dart';

/// Общие рисовалки для иллюстраций из `lib/test/animations/`.
///
/// Своя копия `_drawText` была уже в `decision_tree_widget.dart`; чтобы не
/// плодить четвёртую, текст на холсте рисуется отсюда.

/// Рисует [text] на холсте, привязывая его к точке [anchorPoint].
///
/// [anchor] задаёт, какой угол/сторона блока текста попадает в эту точку:
/// [Alignment.center] — центр (подпись под фигурой), [Alignment.centerLeft] —
/// левый край при той же высоте (строка списка).
///
/// `fontFamily` задаётся всегда: без него `TextPainter` берёт системный шрифт,
/// а в тестовом рендере — заглушку с квадратными глифами.
void drawCanvasText(
  Canvas canvas,
  String text,
  Offset anchorPoint,
  Color color, {
  required double maxWidth,
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  TextAlign textAlign = TextAlign.center,
  Alignment anchor = Alignment.center,
  double lineHeight = 1.2,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: kAppFontFamily,
        height: lineHeight,
        letterSpacing: letterSpacing,
      ),
    ),
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  painter.paint(
    canvas,
    Offset(
      anchorPoint.dx - painter.width * (anchor.x + 1) / 2,
      anchorPoint.dy - painter.height * (anchor.y + 1) / 2,
    ),
  );
}

/// Ширина строки [text] при тех же настройках, что и у [drawCanvasText].
/// Нужна, когда элементы выкладываются в ряд и надо знать, сколько они займут.
double measureCanvasText(
  String text, {
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: kAppFontFamily,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}
