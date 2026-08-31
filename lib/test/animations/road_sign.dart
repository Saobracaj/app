import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  /// прямоугольникам [TappableSigns] ловит нажатия и ставит hero-копию.
  /// Координаты те же, что у painter'а, поэтому слой нажатий обязан лежать
  /// ровно на его CustomPaint.
  final Map<String, PaintedSign> _painted = {};

  /// Знаки, которые холст сейчас не рисует: пока знак летит в просмотрщик и
  /// обратно, его место занимает hero-копия [TappableSigns] — иначе под
  /// улетающим знаком оставался бы его двойник. Место в [_painted] знак
  /// сохраняет, так что нажатия по нему работают по-прежнему.
  final Set<String> _hidden = {};

  /// Рисует знак [sign] вписанным в [target] (contain, по центру).
  /// Пока SVG не загружен — no-op (кадр без знака).
  void paint(Canvas canvas, String sign, Rect target, {double opacity = 1}) {
    final key = sign.toLowerCase();
    final info = _cache[key];
    if (info == null) {
      return;
    }
    _painted[key] = PaintedSign(target, opacity);
    if (_hidden.contains(key)) {
      return;
    }
    _draw(canvas, info, target, opacity);
  }

  /// Знак [sign] на холсте [TappableSigns] или null, если он ещё не рисовался.
  PaintedSign? painted(String sign) => _painted[sign.toLowerCase()];

  /// Спрятан ли знак на время hero-полёта (см. [_hidden]).
  @visibleForTesting
  bool isHidden(String sign) => _hidden.contains(sign.toLowerCase());

  /// Рисует загруженный знак в [target] без записи в [_painted] — так
  /// hero-копия рисует себя в собственных координатах, не сбивая
  /// прямоугольник знака на холсте.
  static void _draw(
    Canvas canvas,
    PictureInfo info,
    Rect target,
    double opacity,
  ) {
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
      if (entry.value.rect.contains(position)) return entry.key;
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

/// Как знак лёг на холст в последнем кадре: прямоугольник и прозрачность —
/// ровно то, что нужно hero-копии, чтобы встать на его место неотличимо.
class PaintedSign {
  const PaintedSign(this.rect, this.opacity);

  final Rect rect;
  final double opacity;
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
/// открывает тот же просмотрщик, что и тап по знаку в конспекте, — и с тем же
/// hero-полётом.
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
///
/// Полёт: знак на холсте — не виджет, лететь ему нечем, поэтому на время
/// открытия просмотрщика слой ставит поверх холста [Hero]-копию знака ровно в
/// его прямоугольнике, а сам холст этот знак перестаёт рисовать
/// ([RoadSigns._hidden]) — иначе улетающий знак оставлял бы за собой двойника.
/// Копия стоит до конца обратного перелёта и снимается, когда холст снова
/// рисует знак сам. Stateful ровно ради этого: состояние — чисто визуальное.
class TappableSigns extends StatefulWidget {
  const TappableSigns({super.key, required this.signs, required this.child});

  final RoadSigns signs;
  final Widget child;

  @override
  State<TappableSigns> createState() => _TappableSignsState();
}

class _TappableSignsState extends State<TappableSigns> {
  /// Знак, который сейчас летит в просмотрщик или обратно.
  _FlyingSign? _flying;

  /// Дёргает перерисовку холста, когда знак прячется или возвращается:
  /// статичная сцена (и остановленная анимация) сама кадр не обновит.
  final _repaint = _RepaintTrigger();

  @override
  void dispose() {
    _repaint.dispose();
    super.dispose();
  }

  Future<void> _open(String sign) async {
    final signs = widget.signs;
    final painted = signs.painted(sign);
    if (painted == null || _flying != null) return;
    final flying = _FlyingSign(sign, painted, Object());
    signs._hidden.add(sign);
    setState(() => _flying = flying);
    _repaint.fire();
    await showRoadSignViewer(context, sign: sign, heroTag: flying.tag);
    signs._hidden.remove(sign);
    if (mounted) {
      setState(() => _flying = null);
      _repaint.fire();
    }
  }

  @override
  Widget build(BuildContext context) {
    final flying = _flying;
    return Stack(
      children: [
        _Repaintable(trigger: _repaint, child: widget.child),
        if (flying != null)
          Positioned.fromRect(
            rect: flying.painted.rect,
            child: IgnorePointer(
              child: Hero(
                tag: flying.tag,
                child: CustomPaint(painter: _SignCopyPainter(flying)),
              ),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTapUp: (details) {
              final sign = widget.signs.signAt(details.localPosition);
              if (sign != null) _open(sign);
            },
            // Курсор-«рука» только над знаком: область под регионом занята
            // лишь там, где нарисованы знаки, а сам регион не должен
            // перехватывать нажатия мимо них.
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              hitTestBehavior: HitTestBehavior.deferToChild,
              child: _SignHitArea(widget.signs),
            ),
          ),
        ),
      ],
    );
  }
}

/// Знак в полёте: где он стоял на холсте и под каким тегом летит.
class _FlyingSign {
  const _FlyingSign(this.sign, this.painted, this.tag);

  final String sign;
  final PaintedSign painted;
  final Object tag;
}

/// Hero-копия знака: тот же загруженный SVG, что рисует холст, — встаёт на
/// место спрятанного знака пиксель в пиксель.
class _SignCopyPainter extends CustomPainter {
  _SignCopyPainter(this.flying);

  final _FlyingSign flying;

  @override
  void paint(Canvas canvas, Size size) {
    final info = RoadSigns._cache[flying.sign.toLowerCase()];
    if (info == null) return;
    RoadSigns._draw(canvas, info, Offset.zero & size, flying.painted.opacity);
  }

  @override
  bool shouldRepaint(_SignCopyPainter oldDelegate) =>
      oldDelegate.flying != flying;
}

/// Сигнал «перерисуй холст» для [_Repaintable].
class _RepaintTrigger extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Перерисовывает своё поддерево по сигналу [trigger]: CustomPaint сцены
/// ниже не отделён границей перерисовки, поэтому его painter отрабатывает
/// заново и видит, что знак спрятан (или вернулся).
class _Repaintable extends SingleChildRenderObjectWidget {
  const _Repaintable({required this.trigger, required super.child});

  final Listenable trigger;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRepaintable(trigger);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRepaintable renderObject,
  ) {
    renderObject.trigger = trigger;
  }
}

class _RenderRepaintable extends RenderProxyBox {
  _RenderRepaintable(this._trigger);

  Listenable _trigger;

  set trigger(Listenable value) {
    if (identical(value, _trigger)) return;
    if (attached) {
      _trigger.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _trigger = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _trigger.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _trigger.removeListener(markNeedsPaint);
    super.detach();
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
