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

/// Полноэкранный просмотр дорожного знака: крупное изображение (с hero-полётом
/// от знака, по которому нажали), название и описание из правилника и ссылка
/// на его абзац. Как и в законе, текст по умолчанию сербский, перевод — чипом
/// «РУ» за фичей russian_content.
Future<void> showRoadSignViewer(
  BuildContext context, {
  required String sign,
  Object? heroTag,
  bool showPravilnikLink = true,
}) {
  // Как просмотр фотографий чата: маршрут прозрачный, пока летит hero, под
  // знаком просвечивает конспект, и фон набирает плотность к концу перехода.
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => RoadSignViewer(
        sign: sign,
        heroTag: heroTag,
        showPravilnikLink: showPravilnikLink,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Экран одного знака. Stateful ровно ради переключателя языка — состояние
/// чисто визуальное, как у чипа «РУ» на экране закона.
class RoadSignViewer extends StatefulWidget {
  RoadSignViewer({
    super.key,
    required this.sign,
    this.heroTag,
    this.showPravilnikLink = true,
  }) : info = RoadSignIndex.find(sign);

  final String sign;

  /// Тег hero знака-источника; null — открытие без полёта.
  final Object? heroTag;

  /// Ссылку «Открыть в правилнике» прячет сам правилник: оттуда она вела бы
  /// на уже открытый документ.
  final bool showPravilnikLink;

  /// Сведения из правилника; индекс собирается один раз, повторные открытия
  /// отвечают мгновенно.
  final Future<RoadSignInfo?> info;

  @override
  State<RoadSignViewer> createState() => _RoadSignViewerState();
}

class _RoadSignViewerState extends State<RoadSignViewer> {
  bool _isSr = true;

  String get _code => widget.sign.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_code),
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
          final name = _isSr ? info?.nameSr : info?.nameRu ?? info?.nameSr;
          final description = _isSr
              ? info?.descriptionSr
              : info?.descriptionRu ?? info?.descriptionSr;
          final image = SvgPicture.asset(asset, fit: BoxFit.contain);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Center(
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
              const SizedBox(height: 24),
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
              if (widget.showPravilnikLink && info != null) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(LocaleKeys.roadSign_openInPravilnik.tr()),
                    onPressed: () => openZakon(
                      context,
                      'pravilnik',
                      queryParameters: {
                        if (info.chapter != null) 'chapter': info.chapter!,
                        if (info.chlan != null) 'chlan': info.chlan!,
                        if (info.paragraph != null) 'paragraph': info.paragraph!,
                      },
                    ),
                  ),
                ),
              ],
            ],
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
    this.showPravilnikLink = true,
  });

  /// Номер знака из правилника, например `'II-2'` (регистр не важен).
  final String sign;
  final double? width;
  final double? height;

  /// См. [RoadSignViewer.showPravilnikLink].
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
