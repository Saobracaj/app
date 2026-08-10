// easy_localization реэкспортирует intl со своим TextDirection — прячем его,
// чтобы в файле остался TextDirection из Flutter (нужен TextPainter'у).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/painters.dart';
import 'package:saobracaj/test/animations/police_officer.dart';

/// Пять положений рук уполномоченного лица и их значения.
///
/// В вопросах категории 32 показывают одну позу и просят приказ — поэтому поза
/// нарисована крупно, а подпись под ней дана теми же словами, которыми написан
/// правильный вариант ответа (*обавезно заустављање*, *забрана пролаза*,
/// *смањи брзину*, *убрзај*). Дорисованные к рукам стрелки и крест нужны,
/// чтобы позы не путались между собой на стоп-кадре: без них «предручена» и
/// «одручене» руки выглядят почти одинаково.
class ZnaciPolicajca extends StatelessWidget {
  const ZnaciPolicajca({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 400,
          height: 486,
          child: CustomPaint(
            painter: _ZnaciPolicajcaPainter(
              Theme.of(context).colorScheme,
              _ZnaciLabels.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Русское пояснение внизу схемы. Сами приказы — сербские термины из правил,
/// они не переводятся и живут в painter'е.
class _ZnaciLabels {
  const _ZnaciLabels({required this.note});

  factory _ZnaciLabels.of(BuildContext context) => _ZnaciLabels(
        note: context.tr(LocaleKeys.znaciPolicajca_note),
      );

  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _ZnaciLabels && other.note == note;

  @override
  int get hashCode => note.hashCode;
}

/// Одна клетка схемы: поза, её приказ и уточнение.
class _PoseCell {
  const _PoseCell(this.pose, this.title, this.detail);

  final OfficerPose pose;

  /// Приказ — словами правильного ответа.
  final String title;

  /// Чем эта поза отличается от соседней.
  final String detail;
}

class _ZnaciPolicajcaPainter extends IllustrationPainter {
  _ZnaciPolicajcaPainter(super.colorScheme, this.labels);

  final _ZnaciLabels labels;

  static const _cells = <_PoseCell>[
    _PoseCell(
      OfficerPose.stop,
      'обавезно\nзаустављање',
      'рука увис,\nдлан и груди\nпрема теби',
    ),
    _PoseCell(
      OfficerPose.forwardArm,
      'забрана пролаза',
      'предручена рука:\nстоји онај чији\nсмер је сече',
    ),
    _PoseCell(
      OfficerPose.armsAside,
      'бочни пролазе',
      'одручене руке:\nчеони и они иза\n— стоје',
    ),
    _PoseCell(
      OfficerPose.slowDown,
      'смањи брзину',
      'длан надоле,\nпокрети горе-доле',
    ),
    _PoseCell(
      OfficerPose.speedUp,
      'убрзај кретање',
      'рука савијена у лакту,\nкружни покрети шаком',
    ),
  ];

  static const _cellWidth = 128.0;
  static const _cellHeight = 206.0;
  static const _figureHeight = 92.0;

  /// Клетки: три сверху, две по центру снизу — так подписи получают ширину
  /// 128 px и не рассыпаются на строки по одному слову.
  Rect _cellRect(int i) {
    final top = i < 3 ? 4.0 : 4.0 + _cellHeight + 8;
    final left = i < 3 ? 4.0 + i * (_cellWidth + 4) : 70.0 + (i - 3) * (_cellWidth + 4);
    return Rect.fromLTWH(left, top, _cellWidth, _cellHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _cells.length; i++) {
      _drawCell(canvas, i, _cellRect(i), _cells[i]);
    }

    calloutBox(
      canvas,
      labels.note,
      const Rect.fromLTRB(6, 428, 394, 482),
      fill: colorScheme.primaryContainer,
      textColor: colorScheme.onPrimaryContainer,
      fontSize: 11,
    );
  }

  void _drawCell(Canvas canvas, int index, Rect rect, _PoseCell cell) {
    panelFrame(canvas, rect, fill: colorScheme.surfaceContainerHighest);

    canvas.drawCircle(
      Offset(rect.left + 18, rect.top + 18),
      11,
      Paint()
        ..color = colorScheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    text(
      canvas,
      '${index + 1}',
      Offset(rect.left + 18, rect.top + 18),
      colorScheme.onSurface,
      maxWidth: 20,
      fontSize: 12,
      isBold: true,
    );

    final cx = rect.center.dx;
    final hands = drawPoliceOfficer(
      canvas,
      colorScheme,
      Offset(cx, rect.top + 126),
      _figureHeight,
      pose: cell.pose,
    );
    _drawPoseMarks(canvas, cell.pose, hands);

    // Подписи выкладываем сверху вниз по измеренной высоте: у клеток разное
    // число строк, и фиксированные координаты одна на всех их бы наложили.
    var y = rect.top + 138.0;
    final titleSize = measure(
      cell.title,
      maxWidth: rect.width - 12,
      fontSize: 12,
      isBold: true,
    );
    text(
      canvas,
      cell.title,
      Offset(cx, y + titleSize.height / 2),
      colorScheme.onSurface,
      maxWidth: rect.width - 12,
      fontSize: 12,
      isBold: true,
    );
    y += titleSize.height + 5;
    final detailSize = measure(cell.detail, maxWidth: rect.width - 12, fontSize: 10);
    text(
      canvas,
      cell.detail,
      Offset(cx, y + detailSize.height / 2),
      colorScheme.onSurfaceVariant,
      maxWidth: rect.width - 12,
      fontSize: 10,
    );
  }

  /// Стрелки и крест около рук: они и есть отличие поз друг от друга.
  void _drawPoseMarks(Canvas canvas, OfficerPose pose, OfficerHands hands) {
    switch (pose) {
      case OfficerPose.stop:
        break;

      case OfficerPose.forwardArm:
        // Продолжение руки пунктиром и поперечный поток, который её пересекает:
        // именно он и стоит.
        dashedLine(
          canvas,
          hands.active.translate(8, 0),
          hands.active.translate(30, 0),
          color: colorScheme.outline,
          dash: 5,
          gap: 3,
        );
        arrow(
          canvas,
          hands.active.translate(19, 24),
          hands.active.translate(19, -24),
          color: colorScheme.error,
          width: 2.5,
          head: 8,
        );
        drawCross(
          canvas,
          hands.active.translate(19, 1),
          6,
          colorScheme.error,
          width: 3,
        );

      case OfficerPose.armsAside:
        // Боковые потоки едут — стрелки наружу от обеих ладоней.
        arrow(
          canvas,
          hands.active.translate(4, -15),
          hands.active.translate(20, -15),
          color: colorScheme.tertiary,
          width: 2.5,
          head: 8,
        );
        final left = hands.second;
        if (left != null) {
          arrow(
            canvas,
            left.translate(-4, -15),
            left.translate(-20, -15),
            color: colorScheme.tertiary,
            width: 2.5,
            head: 8,
          );
        }

      case OfficerPose.slowDown:
        // Махи ладонью вверх-вниз.
        arrow(
          canvas,
          hands.active.translate(16, 0),
          hands.active.translate(16, -14),
          color: colorScheme.primary,
          width: 2,
          head: 7,
        );
        arrow(
          canvas,
          hands.active.translate(16, 0),
          hands.active.translate(16, 14),
          color: colorScheme.primary,
          width: 2,
          head: 7,
        );

      case OfficerPose.speedUp:
        drawCircularArrow(
          canvas,
          hands.active.translate(2, -4),
          13,
          colorScheme.primary,
          strokeWidth: 2.2,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ZnaciPolicajcaPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme || oldDelegate.labels != labels;
}
