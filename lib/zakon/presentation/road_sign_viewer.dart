import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:saobracaj/core/presentation/translation_chip.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_gate.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/test/animations/road_sign.dart';
import 'package:saobracaj/zakon/domain/road_sign_index.dart';
import 'package:saobracaj/zakon/presentation/zakon_panel.dart';

/// Насколько далеко нужно утащить знак, чтобы отпускание закрыло просмотр
/// (те же числа, что у просмотра фотографий чата).
const double _dismissDistance = 120;
const double _dismissVelocity = 700;

/// Полноэкранный просмотр дорожного знака: крупное изображение (с hero-полётом
/// от знака, по которому нажали), название и описание из правилника и ссылка
/// на его абзац. Как и в законе, текст по умолчанию сербский, перевод — чипом
/// «РУ» за фичей russian_content.
///
/// Открывается откуда угодно — из конспекта, из вопроса, из иллюстрации, из
/// самого правилника, — поэтому маршрут кладётся поверх всего стека, как
/// просмотр фотографий чата, и ничего в навигации не занимает. Ссылка «Открыть
/// в правилнике» по той же причине не переходит из просмотрщика: сначала он
/// закрывается, и только потом адрес открывается от экрана-хозяина ([context]).
/// Иначе документ оказался бы ПОД просмотром знака, а «назад» — на «страница
/// не найдена» (относительный адрес разрешался бы от чужого пути).
Future<void> showRoadSignViewer(
  BuildContext context, {
  required String sign,
  String? documentCode,
  Object? heroTag,
  bool showPravilnikLink = true,
}) {
  // Как просмотр фотографий чата: маршрут прозрачный, пока летит hero, под
  // знаком просвечивает конспект, и фон набирает плотность к концу перехода.
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => RoadSignViewer(
        sign: sign,
        documentCode: documentCode,
        heroTag: heroTag,
        onOpenPravilnik: !showPravilnikLink
            ? null
            : (info) {
                navigator.pop();
                if (!context.mounted) return;
                openZakon(
                  context,
                  'pravilnik',
                  queryParameters: {
                    if (info.chapter != null) 'chapter': info.chapter!,
                    if (info.chlan != null) 'chlan': info.chlan!,
                    if (info.paragraph != null) 'paragraph': info.paragraph!,
                  },
                );
              },
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Экран одного знака. Stateful ради переключателя языка и смахивания —
/// состояние чисто визуальное, как у чипа «РУ» на экране закона.
class RoadSignViewer extends StatefulWidget {
  RoadSignViewer({
    super.key,
    required this.sign,
    this.documentCode,
    this.heroTag,
    this.onOpenPravilnik,
  }) : info = RoadSignIndex.find(sign, documentCode: documentCode);

  /// Имя файла знака в assets/signs/ («ii-2», регистр не важен).
  final String sign;

  /// Точный код знака из подписи правилника («III-19»), когда просмотр открыт
  /// из самого документа: описание ищется по нему, и показывается именно он —
  /// имя файла может значить другой номер (нумерации 2010 и 2017 разошлись).
  final String? documentCode;

  /// Тег hero знака-источника; null — открытие без полёта.
  final Object? heroTag;

  /// Как открыть абзац правилника. null — ссылки нет: так просмотрщик
  /// открывается из самого правилника, где переходить некуда.
  final void Function(RoadSignInfo info)? onOpenPravilnik;

  /// Сведения из правилника; индекс собирается один раз, повторные открытия
  /// отвечают мгновенно.
  final Future<RoadSignInfo?> info;

  @override
  State<RoadSignViewer> createState() => _RoadSignViewerState();
}

class _RoadSignViewerState extends State<RoadSignViewer> {
  bool _isSr = true;

  /// Насколько знак утащен от центра, пока палец на экране.
  Offset _drag = Offset.zero;

  String get _code => widget.documentCode ?? widget.sign.toUpperCase();

  /// Плотность фона: к моменту, когда отпускание закроет просмотр, под знаком
  /// уже виден конспект — жест сразу показывает, куда вернёшься.
  double get _backdrop =>
      (1 - _drag.dy.abs() / _dismissDistance).clamp(0.0, 1.0);

  /// Доля пути до закрытия, 0..1 — по ней уменьшается знак.
  double get _progress =>
      (_drag.dy.abs() / (_dismissDistance * 2)).clamp(0.0, 1.0);

  void _onDragUpdate(DragUpdateDetails details) =>
      setState(() => _drag += details.delta);

  void _onDragEnd(DragEndDetails details) =>
      _settle(details.velocity.pixelsPerSecond.dy);

  /// Палец отпущен: далеко или быстро — закрыть, иначе вернуть знак на место.
  void _settle(double velocityY) {
    final far = _drag.dy.abs() > _dismissDistance;
    final fast = velocityY.abs() > _dismissVelocity;
    if (far || fast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _drag = Offset.zero);
  }

  /// Смахивание с любого места экрана, а не только со знака: пока списку есть
  /// куда прокручиваться — он прокручивается, а перетаскивание за край (или
  /// когда всё помещается на экран) утаскивает знак тем же жестом, что и
  /// перетаскивание самого знака. Кламп-физика превращает движение пальца за
  /// краем в [OverscrollNotification] с точной величиной.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      // Только палец: баллистический долёт списка до края знак не трогает.
      if (notification.dragDetails != null) {
        setState(() => _drag += Offset(0, -notification.overscroll));
      }
    } else if (notification is ScrollUpdateNotification) {
      // Палец вернулся в зону прокрутки — знак возвращается на место.
      if (_drag != Offset.zero && notification.dragDetails != null) {
        setState(() => _drag = Offset.zero);
      }
    } else if (notification is ScrollEndNotification) {
      if (_drag != Offset.zero) {
        _settle(notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withValues(alpha: _backdrop),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Opacity(opacity: _backdrop, child: Text(_code)),
        actions: [
          FeatureGate(
            feature: AppFeature.russianContent,
            child: TranslationChip(
              on: !_isSr,
              onTap: () => setState(() => _isSr = !_isSr),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<RoadSignInfo?>(
        future: widget.info,
        builder: (context, snapshot) {
          final info = snapshot.data;
          // Изображение — всегда файл нажатого знака: для вариантов вроде
          // «ii-30-40» описание находится у базового II-30, но картинка
          // должна остаться вариантной. Пока индекс собирается (или знака в
          // правилнике нет) — просто знак без описания.
          final asset = RoadSignSvg.assetPath(widget.sign);
          // Номер знака под изображением — только достоверный: код из подписи
          // правилника или код документа, показывающего ровно этот файл. У
          // знака образца 2017 года с описанием от двойника 2010-го номера
          // двойника на экране быть не должно.
          final code = widget.documentCode ??
              (info != null && info.asset == asset ? info.code : null);
          final name = _isSr ? info?.nameSr : info?.nameRu ?? info?.nameSr;
          final description = _isSr
              ? info?.descriptionSr
              : info?.descriptionRu ?? info?.descriptionSr;
          final image = SvgPicture.asset(asset, fit: BoxFit.contain);
          return NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              // Всегда принимать перетаскивание (даже когда всё помещается) и
              // не пружинить на краях: движение за краем целиком уходит в
              // overscroll-уведомления и становится смахиванием.
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              children: [
                // Смахивание вверх/вниз закрывает просмотр — как в чате. На
                // самом знаке жест свой (список его перехватил бы), на
                // остальной области работает через overscroll списка.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: Transform.translate(
                    offset: _drag,
                    child: Transform.scale(
                      scale: 1 - _progress * 0.2,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 280,
                            maxHeight: 280,
                          ),
                          child: widget.heroTag == null
                              ? image
                              : Hero(tag: widget.heroTag!, child: image),
                        ),
                      ),
                    ),
                  ),
                ),
                // Текст уходит вместе с фоном: к концу жеста на экране остаётся
                // только знак, летящий обратно на своё место.
                Opacity(
                  opacity: _backdrop,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      if (code != null) ...[
                        Text(
                          code,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (name != null)
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                      if (description != null) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: MarkdownBody(data: _plain(description)),
                          ),
                        ),
                      ],
                      if (widget.onOpenPravilnik != null && info != null) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.menu_book_outlined),
                            label: Text(LocaleKeys.roadSign_openInPravilnik.tr()),
                            onPressed: () => widget.onOpenPravilnik!(info),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Текст без служебных `<sup>`-обёрток исходного документа (как в законе).
  static String _plain(String text) =>
      text.split('<sup>').join('').split('</sup>').join('');
}

/// Дорожный знак, открывающий по нажатию [RoadSignViewer] с hero-полётом.
/// Так знаки вставляют конспекты (маркер `anim/sign-ii-2`) и сам правилник.
///
/// Stateful ровно ради тега hero: он должен быть уникален на экземпляр (один
/// знак может встретиться на экране несколько раз, а два одинаковых тега
/// ломают перелёт) и стабилен между перестройками.
class TappableRoadSign extends StatefulWidget {
  const TappableRoadSign(
    this.sign, {
    super.key,
    this.width,
    this.height,
    this.documentCode,
    this.showPravilnikLink = true,
  });

  /// Номер знака из правилника, например `'II-2'` (регистр не важен).
  final String sign;
  final double? width;
  final double? height;

  /// Точный код знака из подписи документа — передаёт экран правилника, где
  /// пары «картинка ↔ код» известны (см. [RoadSignViewer.documentCode]).
  final String? documentCode;

  /// Ссылку «Открыть в правилнике» прячет сам правилник: оттуда она вела бы
  /// на уже открытый документ.
  final bool showPravilnikLink;

  @override
  State<TappableRoadSign> createState() => _TappableRoadSignState();
}

class _TappableRoadSignState extends State<TappableRoadSign> {
  final Object _heroTag = Object();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showRoadSignViewer(
          context,
          sign: widget.sign,
          documentCode: widget.documentCode,
          heroTag: _heroTag,
          showPravilnikLink: widget.showPravilnikLink,
        ),
        child: Hero(
          tag: _heroTag,
          child: RoadSignSvg(
            widget.sign,
            width: widget.width,
            height: widget.height,
          ),
        ),
      ),
    );
  }
}
