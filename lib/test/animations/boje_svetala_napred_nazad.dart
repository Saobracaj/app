import 'package:flutter/material.dart';
import 'package:saobracaj/test/animations/infografika_common.dart';
import 'package:saobracaj/test/animations/vozilo_bocno.dart';

/// Цвета огней спереди и сзади — таблица из конспекта, показанная на самом ТС.
///
/// Вопросы №8719, 8737, 8732, 10653, 8735, 8772 спрашивают цвет по одному
/// прибору за раз, а №8711 и 8712 — общее правило «спереди не красное, сзади
/// не белое». Списком это шесть строк, которые путаются между собой; на двух
/// проекциях каждый прибор стоит там, где он и есть на машине, и цвет
/// запоминается вместе с местом.
///
/// Оговорка «осим у случајевима предвиђеним прописима» из правильных ответов
/// показана явно: белое сзади — это фонарь заднего хода и подсветка номера,
/// то есть запрет не абсолютный.
class BojeSvetalaNapredNazad extends StatelessWidget {
  const BojeSvetalaNapredNazad({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 500,
          child: CustomPaint(painter: _ScenePainter(scheme, Gloss.of(context))),
        ),
      ),
    );
  }
}

/// Цвета самих огней — содержание картинки, поэтому литеральные и одинаковые
/// на обеих темах.
const _kBelo = Color(0xFFFFFDF2);
const _kZuto = Color(0xFFFFC107);
const _kCrveno = Color(0xFFE53935);

class _ScenePainter extends VoziloScenePainter {
  _ScenePainter(super.colorScheme, this.gloss);

  final Gloss gloss;

  @override
  void paint(Canvas canvas, Size size) {
    chip(
      canvas,
      'БОЈЕ СВЕТАЛА${gloss(' · спереди белое, сзади красное')}',
      const Rect.fromLTRB(2, 2, 398, 32),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 12.5,
    );

    _front(canvas);
    _rear(canvas);

    chip(
      canvas,
      'боју светала одређују прописи, а не произвођач возила',
      const Rect.fromLTRB(2, 452, 398, 496),
      fill: colorScheme.primaryContainer,
      ink: colorScheme.onPrimaryContainer,
      fontSize: 12,
    );
  }

  /// Вид спереди: белое и жёлтое, красного здесь быть не может.
  void _front(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 40, 398, 240));
    text(canvas, 'СПРЕДА${gloss(' · спереди')}', const Offset(200, 54),
        colorScheme.onSurface, maxWidth: 260, fontSize: 12, isBold: true);

    const body = Rect.fromLTRB(156, 76, 244, 172);
    _carFace(canvas, body, isFront: true);

    // Главные фары и ДХО — белые, стоят парой; поворотники вынесены наружу,
    // противотуманки — ниже всех, в бампере.
    _lamp(canvas, const Rect.fromLTRB(170, 128, 192, 142), _kBelo);
    _lamp(canvas, const Rect.fromLTRB(208, 128, 230, 142), _kBelo);
    _lamp(canvas, const Rect.fromLTRB(170, 146, 192, 152), _kBelo);
    _lamp(canvas, const Rect.fromLTRB(208, 146, 230, 152), _kBelo);
    _lamp(canvas, const Rect.fromLTRB(158, 128, 168, 142), _kZuto);
    _lamp(canvas, const Rect.fromLTRB(232, 128, 242, 142), _kZuto);
    _round(canvas, const Offset(172, 164), 6, _kBelo);
    _round(canvas, const Offset(228, 164), 6, _kZuto);

    _label(canvas, 'главни фарови\nбело', const Offset(74, 92),
        const Offset(140, 100), const Offset(168, 134));
    _label(canvas, 'дневна светла\nсамо бело', const Offset(74, 150),
        const Offset(140, 156), const Offset(168, 149));
    _label(canvas, 'показивачи правца\nжуто', const Offset(324, 92),
        const Offset(260, 100), const Offset(240, 132));
    _label(canvas, 'светла за маглу\nбело или жуто', const Offset(324, 156),
        const Offset(262, 162), const Offset(236, 165));

    _banChip(
      canvas,
      const Rect.fromLTRB(52, 194, 348, 232),
      'напред НЕ СМЕ црвено светло',
      const Offset(72, 213),
      _kCrveno,
    );
  }

  /// Вид сзади: красное — основное, белое разрешено только двум приборам.
  void _rear(Canvas canvas) {
    panel(canvas, const Rect.fromLTRB(2, 248, 398, 444));
    text(canvas, 'ОТПОЗАДИ${gloss(' · сзади')}', const Offset(200, 262),
        colorScheme.onSurface, maxWidth: 260, fontSize: 12, isBold: true);

    const body = Rect.fromLTRB(156, 282, 244, 378);
    _carFace(canvas, body, isFront: false);

    // Кластер фонарей: красное позиционное и стоп, жёлтый поворотник снаружи,
    // белый задний ход с внутренней стороны.
    _lamp(canvas, const Rect.fromLTRB(168, 334, 190, 350), _kCrveno);
    _lamp(canvas, const Rect.fromLTRB(210, 334, 232, 350), _kCrveno);
    _lamp(canvas, const Rect.fromLTRB(156, 334, 166, 350), _kZuto);
    _lamp(canvas, const Rect.fromLTRB(234, 334, 244, 350), _kZuto);
    _lamp(canvas, const Rect.fromLTRB(191, 336, 209, 348), _kBelo);
    // Табличка с подсветкой: два белых огонька над номером.
    plate(canvas, const Rect.fromLTRB(180, 356, 220, 370), 'BG',
        fill: colorScheme.surface, ink: colorScheme.onSurface);
    _round(canvas, const Offset(176, 356), 4, _kBelo);
    _round(canvas, const Offset(224, 356), 4, _kBelo);

    _label(canvas, 'позициона и стоп светла\nцрвено', const Offset(74, 300),
        const Offset(142, 308), const Offset(166, 338));
    _label(canvas, 'светло регистарске\nтаблице · бело', const Offset(74, 362),
        const Offset(142, 368), const Offset(174, 360));
    _label(canvas, 'показивачи правца\nжуто', const Offset(324, 300),
        const Offset(258, 308), const Offset(240, 332));
    _label(canvas, 'светло за вожњу уназад\nбело', const Offset(324, 362),
        const Offset(258, 366), const Offset(206, 350));

    _banChip(
      canvas,
      const Rect.fromLTRB(30, 398, 370, 436),
      'позади НЕ СМЕ бело светло\nосим вожње уназад и таблице',
      const Offset(50, 417),
      _kBelo,
    );
  }

  /// Силуэт «в лоб»: кузов, стекло и колёса. Спереди и сзади он почти
  /// одинаковый — различают их именно огни, поэтому кузов нейтральный.
  void _carFace(Canvas canvas, Rect r, {required bool isFront}) {
    final w = r.width;
    final h = r.height;
    final stroke = Paint()
      ..color = kVoziloStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final shell = RRect.fromRectAndCorners(
      Rect.fromLTRB(r.left, r.top + h * 0.10, r.right, r.bottom - h * 0.06),
      topLeft: Radius.circular(w * 0.18),
      topRight: Radius.circular(w * 0.18),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    );
    canvas.drawRRect(shell, Paint()..color = kVoziloBody);
    canvas.drawRRect(shell, stroke);

    final glass = RRect.fromRectAndRadius(
      Rect.fromLTWH(r.left + w * 0.14, r.top + h * 0.16, w * 0.72, h * 0.22),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(glass, Paint()..color = kVoziloGlass);
    // Дворники спереди — единственная деталь, по которой проекции различимы
    // и без огней.
    if (isFront) {
      final wiper = Paint()
        ..color = kVoziloStroke
        ..strokeWidth = 1.4;
      canvas.drawLine(
        Offset(r.left + w * 0.24, r.top + h * 0.37),
        Offset(r.left + w * 0.40, r.top + h * 0.22),
        wiper,
      );
      canvas.drawLine(
        Offset(r.left + w * 0.56, r.top + h * 0.37),
        Offset(r.left + w * 0.72, r.top + h * 0.22),
        wiper,
      );
    }

    for (final dx in [0.10, 0.90]) {
      canvas.drawRect(
        Rect.fromLTWH(
          r.left + w * dx - w * 0.08,
          r.bottom - h * 0.08,
          w * 0.16,
          h * 0.08,
        ),
        Paint()..color = kVoziloTyre,
      );
    }
  }

  /// Огонь: заливка цветом и мягкое свечение вокруг — иначе жёлтый и белый
  /// прямоугольники на кузове читаются как наклейки.
  void _lamp(Canvas canvas, Rect r, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.inflate(2.5), const Radius.circular(4)),
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()
        ..color = kVoziloStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _round(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius + 2.5,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = kVoziloStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Подпись с выноской: сербский термин и цвет во второй строке.
  void _label(
    Canvas canvas,
    String value,
    Offset center,
    Offset from,
    Offset to,
  ) {
    text(canvas, value, center, colorScheme.onSurface,
        maxWidth: 140, fontSize: 11, isBold: true);
    arrow(canvas, from, to, width: 1.6, head: 7);
  }

  /// Запрет: плашка с кружком-«нельзя» того цвета, о котором идёт речь.
  void _banChip(
    Canvas canvas,
    Rect rect,
    String value,
    Offset iconCenter,
    Color color,
  ) {
    chip(
      canvas,
      value,
      rect,
      fill: colorScheme.errorContainer,
      ink: colorScheme.onErrorContainer,
      fontSize: 11.5,
    );
    canvas.drawCircle(iconCenter, 10, Paint()..color = color);
    // Обводка нужна ради белого кружка: без неё «бело светло» на светлой
    // плашке пропадает, и запрет выглядит пустым.
    canvas.drawCircle(
      iconCenter,
      10,
      Paint()
        ..color = kVoziloStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    banRing(canvas, iconCenter, 12, width: 3);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.gloss != gloss;
}
