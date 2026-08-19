import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Листалка вопросов — обычный [PageView]: содержимое едет за пальцем, сосед
/// виден уже во время протяжки, а не появляется после неё.
///
/// Пришла на смену самодельной [SwipePagination], которая только сдвигала
/// текущий вопрос и подменяла его по факту свайпа (задача 1217635084826817).
/// Здесь же лист вопросов — настоящая страница прокрутки, поэтому и позиция
/// между вопросами непрерывна: [position] отдаёт её наружу, и полоса
/// прогресса подсвечивает текущий вопрос ровно в такт пальцу.
///
/// Кто хозяин номера вопроса. Источник правды — блок прогона: [index]
/// приходит снаружи, и всякое несовпадение с реальной страницей выправляется
/// анимацией ([animateToPage]) — так листают кнопки нижней панели, клавиши
/// ← / → и чипы навигатора. Обратный путь — [onIndexChanged]: палец перевёл
/// страницу, блоку об этом сообщают. Программный переход при этом не
/// принимают за жест: [onLeaving] зовут, только когда протяжка пальцем
/// довела прогон до другого вопроса — записывать ответ дважды нельзя.
///
/// Порог протяжки понижен относительно системного (см. [touchSlop]): текст
/// вопроса и варианты обёрнуты в `SelectionArea`, а она вешает на палец
/// собственный горизонтальный распознаватель. На ощупь он ничего не делает
/// (выделение с пальца начинается долгим тапом), но арену забирает жадно и,
/// будучи ближе к пальцу, при равных порогах объявляется победителем первым —
/// со штатным порогом свайп по самому тексту вопроса просто пропадал. Порог
/// снижен через `MediaQuery.gestureSettings`, то есть для всей страницы
/// разом: вложенная вертикальная прокрутка получает его тоже и на косой
/// протяжке остаётся при своём — при равных порогах спор выигрывает тот, кто
/// ближе к пальцу, а это список. Полностью выиграть у соседа, стоящего ещё
/// ближе, всё равно нельзя: если палец успевает пройти оба порога за один
/// кадр (бросок свыше ~1100 px/s), первым объявляется `SelectionArea`, и
/// такой бросок по тексту вопроса пропадает. Обычный свайп — даже быстрый —
/// идёт мелкими шагами и доходит.
///
/// Мышью страницы не листаются: [PageView] по умолчанию берёт протяжку только
/// с пальца, стилуса и трекпада, а на мыши горизонтальная протяжка — это
/// выделение текста.
class QuestionPager extends StatefulWidget {
  const QuestionPager({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
    required this.onIndexChanged,
    this.onLeaving,
    this.position,
  });

  /// Текущий вопрос прогона по мнению блока.
  final int index;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Палец перевёл прогон на другой вопрос.
  final ValueChanged<int> onIndexChanged;

  /// Прогон уехал с вопроса [index] пальцем — самое время записать выбор,
  /// как это делает кнопка «Дальше». Программные переходы сюда не попадают.
  final ValueChanged<int>? onLeaving;

  /// Непрерывное положение между вопросами (0 — первый, 1.5 — ровно между
  /// вторым и третьим): по нему полоса прогресса ведёт подсветку.
  final ValueNotifier<double>? position;

  /// Длительность и кривая программного перехода — те же, что у раскрытия
  /// полосы прогресса, чтобы движения экрана не спорили друг с другом.
  static const Duration duration = Duration(milliseconds: 280);
  static const Curve curve = Curves.easeOutCubic;

  /// Порог протяжки для страницы (штатный — 18).
  static const double touchSlop = 10;

  @override
  State<QuestionPager> createState() => _QuestionPagerState();
}

class _QuestionPagerState extends State<QuestionPager> {
  late final PageController _controller = PageController(
    initialPage: widget.index,
  );

  /// Вопрос, на котором прогон стоял, когда прокрутка в последний раз
  /// остановилась: с него и уехали, если следующая остановка пришлась на
  /// другую страницу. Заполняется в `initState`, а не лениво: к первой
  /// остановке [QuestionPager.index] успевает стать новым (его меняет
  /// `onPageChanged` ещё под пальцем), и ленивое поле запомнило бы вопрос,
  /// на который прогон едет, вместо того, с которого уехал.
  int _settled = 0;

  /// Ведёт ли текущую прокрутку палец — программный переход ответа не
  /// записывает (его уже записала кнопка).
  bool _dragged = false;

  @override
  void initState() {
    super.initState();
    _settled = widget.index;
    widget.position?.value = widget.index.toDouble();
    _controller.addListener(_reportPosition);
  }

  @override
  void didUpdateWidget(QuestionPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    if (!_controller.hasClients) {
      // Номер сменился раньше, чем страницы разложились: анимировать нечего,
      // но и оставлять листалку на прежней странице нельзя — переставляем её
      // первым же кадром.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        if (_page?.round() == widget.index) return;
        _controller.jumpToPage(widget.index);
        _settled = widget.index;
      });
      return;
    }
    // Страница уже там — так приходит номер, который сам палец и перевёл.
    if (_page?.round() == widget.index) return;
    _controller.animateToPage(
      widget.index,
      duration: QuestionPager.duration,
      curve: QuestionPager.curve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _page => _controller.hasClients ? _controller.page : null;

  void _reportPosition() {
    final page = _page;
    if (page != null) widget.position?.value = page;
  }

  bool _onScroll(ScrollNotification notification) {
    // Вертикальная прокрутка тела вопроса — не наше дело.
    if (notification.depth != 0 || notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _dragged = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      final settled = _page?.round() ?? _settled;
      if (settled != _settled) {
        if (_dragged) widget.onLeaving?.call(_settled);
        _settled = settled;
      }
      _dragged = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        gestureSettings: DeviceGestureSettings(
          touchSlop: QuestionPager.touchSlop,
        ),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.itemCount,
          onPageChanged: (index) {
            if (index != widget.index) widget.onIndexChanged(index);
          },
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}
