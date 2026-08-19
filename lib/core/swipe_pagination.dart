import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Навигация по вопросам свайпом: протяжка влево показывает следующий вопрос,
/// вправо — предыдущий.
///
/// Пальцевый двойник `KeyboardPagination`: те же колбэки, те же правила —
/// `null` означает «в эту сторону идти некуда» (первый или последний вопрос),
/// и такой свайп только пружинит у края, ничего не вызывая. Оба виджета
/// получают одни и те же `QuestActions`, так что свайп записывает ответ и
/// раскрывает верный ровно так же, как кнопка «Дальше» и стрелка →.
///
/// Оборачивает **тело** вопроса, а не весь экран: шапка, полоса прогресса и
/// нижняя панель остаются на месте, едет только содержимое — и свайп по
/// кнопкам панели не листает вопросы.
///
/// Жест берётся только с пальца и стилуса ([PointerDeviceKind.touch],
/// [PointerDeviceKind.stylus]). Мышь и трекпад исключены намеренно: там
/// горизонтальная протяжка — это выделение текста (текст вопроса и варианты
/// обёрнуты в `SelectionArea`) и двухпальцевая прокрутка, отбирать их нельзя.
///
/// Вертикальную прокрутку тела жест не задевает: распознаватель забирает
/// арену, только когда протяжка заведомо горизонтальная — набранный по X путь
/// больше набранного по Y (см. [_SwipeDragRecognizer]). Порог при этом
/// намеренно ниже стандартного `kTouchSlop`, и вот почему: текст вопроса и
/// варианты обёрнуты в `SelectionArea`, а та вешает на палец собственный
/// горизонтальный распознаватель. На ощупь он ничего не делает (выделение с
/// пальца начинается долгим тапом), но арену забирает жадно и, будучи ближе к
/// пальцу, объявляется победителем первым — со стандартным порогом свайп по
/// тексту вопроса на Android просто пропадал. Меньший порог даёт нам
/// объявиться раньше; долгий тап по-прежнему выигрывает у нас обоих, так что
/// выделение текста цело. Полностью выиграть у соседа, стоящего ближе к
/// пальцу, всё равно нельзя: если палец успевает пройти оба порога за один
/// кадр (свыше ~1800 px/s), первым объявляется он, и такой бросок по тексту
/// вопроса пропадает. Обычный свайп — даже быстрый — идёт мелкими шагами и
/// доходит.
///
/// Языки приложения (sr / ru / en) пишутся слева направо, поэтому «влево —
/// вперёд» здесь зашито; при появлении RTL-локали направление придётся
/// разворачивать по [Directionality].
class SwipePagination extends StatefulWidget {
  const SwipePagination({
    super.key,
    this.onPrevious,
    this.onNext,
    required this.child,
  });

  /// Свайп вправо (палец идёт вправо) — предыдущий вопрос.
  final VoidCallback? onPrevious;

  /// Свайп влево — следующий вопрос.
  final VoidCallback? onNext;

  final Widget child;

  /// Насколько далеко уезжает содержимое за пальцем (доля пройденного пути).
  static const double _followFactor = 0.55;

  /// То же у края прогона, где идти некуда: почти не поддаётся — это и есть
  /// сигнал «дальше ничего нет».
  static const double _edgeFollowFactor = 0.16;

  /// Потолок сдвига: доля ширины тела и абсолютный предел.
  static const double _maxOffsetFraction = 0.3;
  static const double _maxOffset = 140;
  static const double _maxEdgeOffset = 28;

  /// Порог перелистывания: доля ширины тела, но не больше этого.
  static const double _commitFraction = 0.25;
  static const double _maxCommitDistance = 96;

  /// Быстрый бросок листает и с меньшего пути — но не с дрожи пальца.
  static const double _flingVelocity = 420;
  static const double _minFlingDistance = 24;

  /// С какого сдвига въезжает новый вопрос после успешного свайпа.
  static const double _enterOffset = 56;

  static const Duration _settleDuration = Duration(milliseconds: 220);

  @override
  State<SwipePagination> createState() => _SwipePaginationState();
}

class _SwipePaginationState extends State<SwipePagination>
    with SingleTickerProviderStateMixin {
  /// Заводится в `initState`, а не лениво: прогон из одного вопроса вообще не
  /// строит жест (листать некуда), и ленивое поле создавало бы контроллер уже
  /// в `dispose`, на отцеплённом от дерева элементе.
  late final AnimationController _settle;

  /// Возврат сдвига к нулю: и пружина несостоявшегося свайпа, и въезд нового
  /// вопроса — одно и то же движение, отличается только начальная точка.
  Animation<double> _settleOffset = const AlwaysStoppedAnimation(0);

  /// Путь, пройденный пальцем с начала жеста (влево — отрицательный).
  double _travel = 0;

  /// Куда при этом уехало содержимое: считается в обработчиках жеста, а не в
  /// `build` — размеры там ещё не известны.
  double _offset = 0;

  /// Ширина тела вопроса, снятая на старте жеста: пороги считаются от неё, а
  /// не от окна — на широком экране вопрос занимает лишь часть ширины.
  double _width = 0;

  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: SwipePagination._settleDuration,
    );
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Листать некуда — не мешаем ни выделению текста, ни прокрутке.
    if (widget.onPrevious == null && widget.onNext == null) return widget.child;
    return RawGestureDetector(
      // Промежутки между элементами тела тоже листают.
      behavior: HitTestBehavior.opaque,
      gestures: {
        _SwipeDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_SwipeDragRecognizer>(
              () => _SwipeDragRecognizer(debugOwner: this),
              (instance) => instance
                ..onStart = _onDragStart
                ..onUpdate = _onDragUpdate
                ..onEnd = _onDragEnd
                ..onCancel = _onDragCancel,
            ),
      },
      child: AnimatedBuilder(
        animation: _settle,
        builder: (context, child) => Transform.translate(
          offset: Offset(_dragging ? _offset : _settleOffset.value, 0),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }

  bool _canGo(double travel) =>
      travel < 0 ? widget.onNext != null : widget.onPrevious != null;

  /// Куда уехало содержимое при пройденном пути [travel].
  double _offsetFor(double travel) {
    if (_canGo(travel)) {
      final limit = math.min(
        _width * SwipePagination._maxOffsetFraction,
        SwipePagination._maxOffset,
      );
      return (travel * SwipePagination._followFactor).clamp(-limit, limit);
    }
    return (travel * SwipePagination._edgeFollowFactor).clamp(
      -SwipePagination._maxEdgeOffset,
      SwipePagination._maxEdgeOffset,
    );
  }

  void _onDragStart(DragStartDetails details) {
    _settle.stop();
    _width = context.size?.width ?? 0;
    setState(() {
      _dragging = true;
      _travel = 0;
      _offset = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _travel += details.delta.dx;
      _offset = _offsetFor(_travel);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final travel = _travel;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (!_commits(travel, velocity) || !_canGo(travel)) {
      _settleFrom(_offsetFor(travel));
      return;
    }
    (travel < 0 ? widget.onNext : widget.onPrevious)!();
    // Новый вопрос въезжает с той стороны, откуда пришёл палец: ушли влево —
    // следующий приходит справа.
    _settleFrom(
      travel < 0 ? SwipePagination._enterOffset : -SwipePagination._enterOffset,
    );
  }

  void _onDragCancel() => _settleFrom(_offset);

  /// Достаточен ли жест, чтобы листать: либо палец увёл содержимое заметно
  /// далеко, либо это был быстрый бросок.
  bool _commits(double travel, double velocity) {
    final distance = travel.abs();
    final threshold = math.min(
      _width * SwipePagination._commitFraction,
      SwipePagination._maxCommitDistance,
    );
    if (distance >= threshold) return true;
    return velocity.abs() >= SwipePagination._flingVelocity &&
        distance >= SwipePagination._minFlingDistance;
  }

  void _settleFrom(double from) {
    setState(() {
      _dragging = false;
      _travel = 0;
      _offset = 0;
      _settleOffset = Tween<double>(
        begin: from,
        end: 0,
      ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    });
    _settle.forward(from: 0);
  }
}

/// Горизонтальная протяжка пальцем, объявляющая победу раньше обычного.
///
/// Отличий от [HorizontalDragGestureRecognizer] два, и оба — про то, у кого
/// отбирать жест (см. документацию [SwipePagination]):
///
/// * порог [_slop] ниже стандартного `kTouchSlop`, чтобы успеть объявиться
///   раньше горизонтального распознавателя `SelectionArea`;
/// * протяжка засчитывается, только пока путь по X перевешивает путь по Y —
///   иначе прокрутка списка (её порог как раз `kTouchSlop`) досталась бы нам
///   при первом же наклонном движении пальца.
class _SwipeDragRecognizer extends HorizontalDragGestureRecognizer {
  _SwipeDragRecognizer({super.debugOwner})
    : super(
        // Мышь и трекпад намеренно не свайпают: там горизонтальная протяжка
        // — выделение текста и двухпальцевая прокрутка.
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );

  static const double _slop = 10;

  /// Путь по вертикали с начала жеста — по X его считает сам базовый класс.
  double _verticalDistanceMoved = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _verticalDistanceMoved = 0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    // Раньше `super`: он тут же спросит, набралось ли расстояние.
    if (event is PointerMoveEvent) _verticalDistanceMoved += event.delta.dy;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final horizontal = globalDistanceMoved.abs();
    return horizontal > _slop && horizontal > _verticalDistanceMoved.abs();
  }
}
