import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:saobracaj/zakon/presentation/road_sign_viewer.dart';

/// Официальные SVG сербских дорожных знаков (Wikimedia Commons,
/// `Category:SVG road signs in Serbia`). Ассеты лежат в `assets/signs/`,
/// имя файла — номер знака из правилника в нижнем регистре: `ii-2.svg`,
/// `iii-78.svg`.
///
/// Знак в иллюстрации можно показать двумя способами:
///
/// 1. как обычный виджет — [RoadSignSvg]: сам грузит ассет, ничего ждать
///    не нужно;
/// 2. внутри `CustomPainter` — обернуть иллюстрацию в [RoadSignScope] со
///    списком нужных знаков; painter получает [RoadSigns] полем и рисует
///    через [RoadSigns.paint]. Когда все SVG распарсены, builder вызывается
///    заново с новым [RoadSigns] — сравнение полей в `shouldRepaint`
///    перерисует холст (в кэше картинки остаются навсегда: знаков мало и
///    они маленькие).
class RoadSignSvg extends StatelessWidget {
  const RoadSignSvg(this.sign, {super.key, this.width, this.height});

  /// Номер знака из правилника, например `'II-2'` (регистр не важен).
  final String sign;
  final double? width;
  final double? height;

  static String assetPath(String sign) =>
      'assets/signs/${sign.toLowerCase()}.svg';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(assetPath(sign), width: width, height: height);
  }
}

/// Набор распарсенных знаков, готовых к синхронному рисованию на canvas.
/// Экземпляр меняется при завершении загрузки — храни его полем painter'а
/// и учитывай в `shouldRepaint`.
class RoadSigns {
  RoadSigns._(this._generation);

  /// Меняется, когда кэш пополнился, — чтобы `oldDelegate.signs != signs`
  /// в `shouldRepaint` замечал дозагрузку.
  final int _generation;

  static final Map<String, PictureInfo> _cache = {};

  /// Где на холсте оказался каждый знак в последнем кадре — по этим
  /// прямоугольникам [TappableSigns] ловит нажатия. Координаты те же, что у
  /// painter'а, поэтому слой нажатий обязан лежать ровно на его CustomPaint.
  final Map<String, Rect> _painted = {};

  /// Рисует знак [sign] вписанным в [target] (contain, по центру).
  /// Пока SVG не загружен — no-op (кадр без знака).
  void paint(Canvas canvas, String sign, Rect target, {double opacity = 1}) {
    final info = _cache[sign.toLowerCase()];
    if (info == null) {
      return;
    }
    _painted[sign.toLowerCase()] = target;
    if (opacity < 1) {
      canvas.saveLayer(
        target.inflate(2),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    } else {
      canvas.save();
    }
    final source = info.size;
    final scale = (target.width / source.width < target.height / source.height)
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

  /// Знак, нарисованный в точке [position] холста, или null.
  String? signAt(Offset position) {
    for (final entry in _painted.entries) {
      if (entry.value.contains(position)) return entry.key;
    }
    return null;
  }

  /// Соотношение сторон знака (ширина/высота) после загрузки, иначе `null`.
  double? aspectRatio(String sign) {
    final info = _cache[sign.toLowerCase()];
    return info == null ? null : info.size.width / info.size.height;
  }

  @override
  bool operator ==(Object other) =>
      other is RoadSigns && other._generation == _generation;

  @override
  int get hashCode => _generation;
}

/// Загружает SVG перечисленных знаков и перестраивает [builder], когда всё
/// готово.
class RoadSignScope extends StatefulWidget {
  const RoadSignScope({super.key, required this.signs, required this.builder});

  final List<String> signs;
  final Widget Function(BuildContext context, RoadSigns signs) builder;

  @override
  State<RoadSignScope> createState() => _RoadSignScopeState();
}

class _RoadSignScopeState extends State<RoadSignScope> {
  static int _generation = 0;

  var _signs = RoadSigns._(_generation);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var missing = false;
    for (final sign in widget.signs) {
      final key = sign.toLowerCase();
      if (RoadSigns._cache.containsKey(key)) {
        continue;
      }
      missing = true;
      final info = await vg.loadPicture(
        SvgAssetLoader(RoadSignSvg.assetPath(key)),
        null,
      );
      RoadSigns._cache[key] = info;
    }
    if (missing && mounted) {
      setState(() => _signs = RoadSigns._(++_generation));
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _signs);
}

/// Слой нажатий над иллюстрацией, рисующей знаки на холсте: тап по знаку
/// открывает тот же просмотрщик, что и тап по знаку в конспекте.
///
/// Оборачивает CustomPaint сцены (и обязан лежать ровно на нём — координаты
/// нажатия сверяются с координатами painter'а):
///
/// ```dart
/// TappableSigns(
///   signs: signs,
///   child: CustomPaint(painter: _ScenePainter(signs)),
/// )
/// ```
///
/// Мимо знака нажатие проходит насквозь — пауза и шаги [InteractiveAnimation]
/// продолжают работать: слой отвечает на нажатие, только когда точка попала в
/// прямоугольник знака из последнего кадра.
class TappableSigns extends StatelessWidget {
  const TappableSigns({super.key, required this.signs, required this.child});

  final RoadSigns signs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTapUp: (details) {
              final sign = signs.signAt(details.localPosition);
              if (sign != null) showRoadSignViewer(context, sign: sign);
            },
            child: _SignHitArea(signs),
          ),
        ),
      ],
    );
  }
}

/// Пустая область, «занятая» только там, где нарисованы знаки: тап мимо знака
/// её не задевает и достаётся тому, кто под ней (сцене с паузой по нажатию).
class _SignHitArea extends LeafRenderObjectWidget {
  const _SignHitArea(this.signs);

  final RoadSigns signs;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSignHitArea(signs);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSignHitArea renderObject,
  ) {
    renderObject.signs = signs;
  }
}

class _RenderSignHitArea extends RenderBox {
  _RenderSignHitArea(this.signs);

  RoadSigns signs;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite ? constraints.biggest : Size.zero;

  @override
  bool hitTestSelf(Offset position) => signs.signAt(position) != null;
}
