import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  const RoadSigns._(this._generation);

  /// Меняется, когда кэш пополнился, — чтобы `oldDelegate.signs != signs`
  /// в `shouldRepaint` замечал дозагрузку.
  final int _generation;

  static final Map<String, PictureInfo> _cache = {};

  /// Рисует знак [sign] вписанным в [target] (contain, по центру).
  /// Пока SVG не загружен — no-op (кадр без знака).
  void paint(Canvas canvas, String sign, Rect target, {double opacity = 1}) {
    final info = _cache[sign.toLowerCase()];
    if (info == null) {
      return;
    }
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
