import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Позы уполномоченного лица (полицейского), которыми он регулирует движение.
///
/// Названия — по значению приказа, а не по анатомии: в вопросах спрашивают
/// именно «шта значи овај положај руку».
enum OfficerPose {
  /// Рука поднята вверх, ладонь и грудь обращены к водителю —
  /// *обавезно заустављање*.
  stop,

  /// Рука предручена (вытянута вперёд-вбок) — *забрана пролаза за оне чији
  /// смер кретања сече смер предручене руке*.
  forwardArm,

  /// Обе руки одручене (разведены горизонтально) — бока едут, чеони стоят.
  armsAside,

  /// Рука в сторону ладонью вниз, лёгкие махи — *смањи брзину*.
  slowDown,

  /// Рука согнута в локте, круговые движения кистью — *убрзај*.
  speedUp,
}

/// Куда пришлись кисти рук после отрисовки фигуры. Нужны вызывающему, чтобы
/// пририсовать к руке стрелку маха, круговую стрелку или пунктир направления —
/// сама фигура таких пояснений не несёт.
class OfficerHands {
  const OfficerHands({required this.active, this.second});

  /// Кисть «говорящей» руки: у [OfficerPose.armsAside] — правая от зрителя.
  final Offset active;

  /// Вторая кисть, если она тоже поднята ([OfficerPose.armsAside]).
  final Offset? second;
}

/// Фигура уполномоченного лица анфас: [feet] — точка между ступнями,
/// [height] — рост от ступней до макушки (без фуражки — она чуть выше).
///
/// Фигура — пиктограмма: узнаётся не анатомией, а формой (фуражка с козырьком
/// и светоотражающий жилет), поэтому её видно и в 40 px, и в 110 px. Силуэт
/// берётся из темы, а жилет — литеральный лимонный: это его собственный цвет,
/// по которому регулировщика и опознают на дороге.
OfficerHands drawPoliceOfficer(
  Canvas canvas,
  ColorScheme scheme,
  Offset feet,
  double height, {
  required OfficerPose pose,
}) {
  final uniform = Paint()..color = scheme.onSurfaceVariant;
  final skin = Paint()..color = scheme.surface;
  final skinOutline = Paint()
    ..color = scheme.onSurfaceVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = height * 0.022;

  final x = feet.dx;
  final hipY = feet.dy - height * 0.36;
  final shoulderY = feet.dy - height * 0.70;
  final headCenter = Offset(x, feet.dy - height * 0.82);
  final headR = height * 0.085;

  final limb = Paint()
    ..color = scheme.onSurfaceVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = height * 0.07
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Ноги.
  canvas.drawLine(
    Offset(x - height * 0.04, hipY),
    Offset(x - height * 0.09, feet.dy),
    limb,
  );
  canvas.drawLine(
    Offset(x + height * 0.04, hipY),
    Offset(x + height * 0.09, feet.dy),
    limb,
  );

  // Туловище.
  final torso = Rect.fromLTRB(
    x - height * 0.14,
    shoulderY,
    x + height * 0.14,
    hipY + height * 0.02,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(torso, Radius.circular(height * 0.05)),
    uniform,
  );

  // Светоотражающий жилет: полоса на груди плюс две вертикальные лямки.
  const vestColor = Color(0xFFD4E157);
  const vestStripe = Color(0xFFF5F5F5);
  final vest = Rect.fromLTRB(
    torso.left,
    torso.top + height * 0.05,
    torso.right,
    torso.bottom - height * 0.04,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(vest, Radius.circular(height * 0.03)),
    Paint()..color = vestColor,
  );
  canvas.drawRect(
    Rect.fromLTRB(
      vest.left,
      vest.center.dy - height * 0.015,
      vest.right,
      vest.center.dy + height * 0.015,
    ),
    Paint()..color = vestStripe,
  );

  // Голова, фуражка и козырёк — по ним фигура читается как «овлашћено лице»,
  // а не как случайный пешеход.
  canvas.drawCircle(headCenter, headR, skin);
  canvas.drawCircle(headCenter, headR, skinOutline);
  final capTop = headCenter.dy - headR * 0.95;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        headCenter.dx - headR * 1.05,
        capTop - headR * 0.75,
        headCenter.dx + headR * 1.05,
        capTop + headR * 0.35,
      ),
      Radius.circular(headR * 0.5),
    ),
    uniform,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(headCenter.dx, capTop + headR * 0.4),
      width: headR * 2.5,
      height: headR * 0.5,
    ),
    uniform,
  );

  // Руки. Плечи чуть ниже верха туловища, иначе рука растёт из шеи.
  final leftShoulder = Offset(x - height * 0.12, shoulderY + height * 0.04);
  final rightShoulder = Offset(x + height * 0.12, shoulderY + height * 0.04);
  final downLeft = Offset(x - height * 0.17, hipY + height * 0.04);
  final downRight = Offset(x + height * 0.17, hipY + height * 0.04);

  void arm(Offset from, List<Offset> joints) {
    var current = from;
    for (final joint in joints) {
      canvas.drawLine(current, joint, limb);
      current = joint;
    }
  }

  /// Открытая ладонь к зрителю: четыре пальца, отставленный большой и сама
  /// кисть. В приказе «стој» смысл несёт именно раскрытая ладонь, поэтому она
  /// рисуется подробнее остальных кистей.
  ///
  /// Порядок важен: пальцы рисуются первыми, кисть поверх них — так их
  /// основания скрыты и рука не распадается на отдельные палочки.
  void openPalm(Offset center) {
    final w = height * 0.17;
    final palm = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: w * 1.15),
      Radius.circular(w * 0.3),
    );
    canvas.drawRRect(palm, skin);
    canvas.drawRRect(palm, skinOutline);

    // Пальцы — не отдельные фигуры, а прорези в кисти: на маленьком масштабе
    // (в пирамиде фигура высотой 44 px) отдельные пальцы слипаются в кляксу.
    final split = Paint()
      ..color = scheme.onSurfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final fx = center.dx - w * 0.25 + i * w * 0.25;
      canvas.drawLine(
        Offset(fx, center.dy - w * 0.5),
        Offset(fx, center.dy - w * 0.05),
        split,
      );
    }
    // Большой палец сбоку — без него кисть читается как варежка.
    canvas.drawLine(
      Offset(center.dx + w * 0.4, center.dy - w * 0.1),
      Offset(center.dx + w * 0.4, center.dy + w * 0.2),
      split,
    );
  }

  void fist(Offset center) {
    canvas.drawCircle(center, height * 0.05, skin);
    canvas.drawCircle(center, height * 0.05, skinOutline);
  }

  /// Ладонь плашмя, вид сбоку — плоская плашка. Так «длан надоле» отличается
  /// от простой вытянутой руки.
  void flatPalm(Offset center) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: height * 0.14,
        height: height * 0.045,
      ),
      Radius.circular(height * 0.02),
    );
    canvas.drawRRect(r, skin);
    canvas.drawRRect(r, skinOutline);
  }

  switch (pose) {
    case OfficerPose.stop:
      final hand = Offset(x + height * 0.16, shoulderY - height * 0.40);
      arm(rightShoulder, [Offset(x + height * 0.19, shoulderY - height * 0.14), hand]);
      arm(leftShoulder, [downLeft]);
      openPalm(hand);
      return OfficerHands(active: hand);

    case OfficerPose.forwardArm:
      // Рука короче, чем у «одручених»: справа от кисти должно остаться место
      // под пунктир продолжения и под поперечный поток.
      final hand = Offset(x + height * 0.36, shoulderY + height * 0.05);
      arm(rightShoulder, [hand]);
      arm(leftShoulder, [downLeft]);
      fist(hand);
      return OfficerHands(active: hand);

    case OfficerPose.armsAside:
      final right = Offset(x + height * 0.44, shoulderY + height * 0.05);
      final left = Offset(x - height * 0.44, shoulderY + height * 0.05);
      arm(rightShoulder, [right]);
      arm(leftShoulder, [left]);
      fist(right);
      fist(left);
      return OfficerHands(active: right, second: left);

    case OfficerPose.slowDown:
      final hand = Offset(x + height * 0.40, shoulderY + height * 0.16);
      arm(rightShoulder, [hand]);
      arm(leftShoulder, [downLeft]);
      flatPalm(hand);
      return OfficerHands(active: hand);

    case OfficerPose.speedUp:
      // Рука согнута в локте: предплечье поднято — по этому излому поза
      // отличается от вытянутой руки даже на стоп-кадре.
      final elbow = Offset(x + height * 0.26, shoulderY + height * 0.14);
      final hand = Offset(x + height * 0.40, shoulderY - height * 0.14);
      arm(rightShoulder, [elbow, hand]);
      arm(leftShoulder, [downRight.translate(-height * 0.34, 0)]);
      fist(hand);
      return OfficerHands(active: hand);
  }
}

/// Круговая стрелка вокруг [center] — «кружни покрети шаком».
void drawCircularArrow(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double strokeWidth = 2,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(
    Rect.fromCircle(center: center, radius: radius),
    -math.pi * 0.85,
    math.pi * 1.5,
    false,
    paint,
  );
  // Наконечник на конце дуги: без него дуга читается как скобка.
  final endAngle = -math.pi * 0.85 + math.pi * 1.5;
  final tip = center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;
  final tangent = endAngle + math.pi / 2;
  final head = radius * 0.55;
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - head * math.cos(tangent - math.pi / 7),
        tip.dy - head * math.sin(tangent - math.pi / 7),
      )
      ..lineTo(
        tip.dx - head * math.cos(tangent + math.pi / 7),
        tip.dy - head * math.sin(tangent + math.pi / 7),
      )
      ..close(),
    Paint()..color = color,
  );
}
