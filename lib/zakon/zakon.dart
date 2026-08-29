import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/core/deep_links.dart';
import 'package:saobracaj/core/presentation/translation_chip.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_gate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';
import 'package:saobracaj/zakon/domain/law_document.dart';
import 'package:saobracaj/zakon/domain/zakon_contents.dart';
import 'package:saobracaj/zakon/state_management/zakon_bloc.dart';
import 'package:flutter/services.dart';

import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class Zakon extends StatefulWidget {
  const Zakon({
    super.key,
    this.paragraph,
    this.chlan,
    this.chapter,
    this.asPanel = false,
    this.document = LawDocument.zakonOBezbednosti,
  });

  final String? paragraph;
  final String? chlan;
  final String? chapter;

  /// Какой документ показан: закон (по умолчанию) или правилник — тот же
  /// виджет, оглавление и ссылки, различаются только данные и заголовок.
  final LawDocument document;

  /// Закон показан выдвижной боковой панелью (см. `openZakon`), а не
  /// страницей: шапку закрывает крестик, а не стрелка «назад», и заголовок
  /// набран мельче — колонка панели уже экрана.
  final bool asPanel;

  @override
  State<Zakon> createState() => _ZakonState();
}

/// Ширина закреплённой колонки с оглавлением на широком экране.
const double _kTocWidth = 300;

class _ZakonState extends State<Zakon> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  /// Оглавление стоит сбоку только на широком экране и только когда закон
  /// открыт страницей: выдвижная панель (`asPanel`) сама узкая колонка, там
  /// оглавление по-прежнему вызывается кнопкой.
  bool _showsSideToc(BuildContext context) =>
      !widget.asPanel && context.isExpandedScreen;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ZakonBloc(
        widget.paragraph,
        widget.chlan,
        widget.chapter,
        dataSource: widget.document.dataSource,
      ),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.asPanel,
          leading: widget.asPanel
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(
            widget.document.title,
            style: widget.asPanel
                ? Theme.of(context).textTheme.titleSmall
                : null,
          ),
          actions: [
            // Та же кнопка «РУ», что и на экране вопроса (вместо прежней
            // безликой иконки translate); isSr — сербский, т.е. перевод выкл.
            FeatureGate(
              feature: AppFeature.russianContent,
              child: BlocBuilder<ZakonBloc, ZakonState>(
                builder: (context, state) {
                  return TranslationChip(
                    on: !state.isSr,
                    onTap: () => context.read<ZakonBloc>().add(ToggleLang()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        // На широком экране оглавление стоит сбоку (см. `_ZakonToc`), и
        // кнопка, открывающая его снизу, там не нужна.
        floatingActionButton: _showsSideToc(context)
            ? null
            : BlocBuilder<ZakonBloc, ZakonState>(
                builder: (context, state) {
                  return FloatingActionButton.extended(
                    onPressed: () async {
                      final res = await _showTableOfContents(context, state);
                      if (res != null && context.mounted) {
                        context.read<ZakonBloc>().add(
                          ScrollTo(res.$1, res.$2, res.$3),
                        );
                      }
                    },
                    tooltip: LocaleKeys.zakon_contents.tr(),
                    label: Icon(Icons.list_alt_outlined),
                  );
                },
              ),
        body: BlocConsumer<ZakonBloc, ZakonState>(
          listener: (context, state) {
            if (state.scrollTo != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _itemScrollController.scrollTo(
                  index: state.scrollTo!,
                  duration: const Duration(milliseconds: 300),
                  alignment: 0.0, // 0.0 = элемент попадёт вверх
                );
              });
            }
          },
          builder: (context, state) {
            final withToc = _showsSideToc(context);
            // Строки закона на всю ширину планшета/окна нечитаемы — колонка
            // ограничена шириной комфортного чтения. Сужаются именно поля, а
            // не сам список: полоса прокрутки должна идти по правому краю
            // окна, а колесо мыши — работать в любой его точке, а не только
            // над колонкой текста.
            final article = ScrollablePositionedList.builder(
              padding: readableInsets(
                context,
                horizontal: 0,
                availableWidth: withToc
                    ? MediaQuery.sizeOf(context).width - _kTocWidth - 1
                    : null,
              ),
              itemCount: state.zakon.length,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              itemBuilder: (context, index) {
                return _Paragraph(
                  paragraph: state.zakon[index],
                  isSerbian: state.isSr,
                  linkPath: widget.document.linkPath,
                );
              },
            );
            if (!withToc) return article;
            // Широкий экран: слева закреплённое оглавление, справа — текст
            // (как в конспектах).
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ZakonToc(
                  paragraphs: state.zakon,
                  isSerbian: state.isSr,
                  onSelected: (p) => context.read<ZakonBloc>().add(
                    ScrollTo(p.paragraph, p.chlan, p.chapter),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: article),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({
    required this.paragraph,
    required this.isSerbian,
    required this.linkPath,
  });

  final BezbParagraph paragraph;
  final bool isSerbian;

  /// Путь документа для копируемой ссылки ('/zakon' или '/pravilnik').
  final String linkPath;

  @override
  Widget build(BuildContext context) {
    String text = isSerbian
        ? (paragraph.sr ?? '')
        : (paragraph.ru ?? paragraph.sr ?? '');

    if (paragraph.isTitle) {
      return InkWell(
        onTap: () => _onTap(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
            // Заголовок и так набран жирным: звёздочки markdown в обычном
            // Text остались бы видны (шапка правилника «**ПРАВИЛНИК**»).
            _plain(text).replaceAll('**', ''),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (paragraph.isChapter) {
      text = '# $text';
    } else if (paragraph.isChlan) {
      text = '## $text';
    }
    final body = Markdown(
      data: _plain(text),
      shrinkWrap: true,
      selectable: false,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
    return InkWell(
      onTap: () => _onTap(context),
      child: paragraph.images.isEmpty
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (text.trim().isNotEmpty) body,
                _ParagraphImages(images: paragraph.images),
              ],
            ),
    );
  }

  /// Текст без служебных `<sup>`-обёрток исходного документа.
  static String _plain(String text) =>
      text.split('<sup>').join('').split('</sup>').join('');

  void _onTap(BuildContext context) {
    final queryParameters = <String, String?>{};

    if (paragraph.chapter != null) {
      queryParameters['chapter'] = paragraph.chapter;
    }

    if (paragraph.chlan != null) {
      queryParameters['chlan'] = paragraph.chlan;
    }

    if (paragraph.paragraph != null) {
      queryParameters['paragraph'] = paragraph.paragraph;
    }

    final uri = appLink(linkPath, queryParameters);

    Clipboard.setData(ClipboardData(text: uri.toString())).then((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Link is copied to clipboard')));
    });
  }
}

/// Изображения строки правилника (дорожные знаки, рисунки): в один ряд, в
/// натуральную величину из документа, а если ряд шире колонки — ужимаются,
/// чтобы ничего не обрезалось.
class _ParagraphImages extends StatelessWidget {
  const _ParagraphImages({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final (i, path) in images.indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                path.endsWith('.svg')
                    ? SvgPicture.asset(path)
                    : Image.asset(path),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<(String?, String?, String?)?> _showTableOfContents(
  BuildContext context,
  ZakonState state,
) async {
  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) {
        final list = zakonTableOfContents(state.zakon);

        return ListView.builder(
          controller: controller,
          itemCount: list.length,
          itemBuilder: (context, index) => _TableOfContentsItem(
            paragraphs: list[index],
            isSerbian: state.isSr,
            onSelected: (p) =>
                Navigator.pop(context, (p.paragraph, p.chlan, p.chapter)),
          ),
        );
        /*
        final allQuestions = context.read<AllQuestionsBloc>().state.questionsData?.questions ?? [];
        List<TableEntry> entries = [];
        for (var i = 0; i < state.questions.length; i++) {
          final q = state.questions[i];
          final question = allQuestions.firstWhere((element) => element.id == q);
          final t = TableEntry(
            question: 'Питање ${i + 1}',
            points: question.points,
            answered: state.answers.containsKey(q),
            marked: state.markedQuestions.contains(i),
          );
          entries.add(t);
        }
        return SingleChildScrollView(controller: controller, child: QuestionsTable(entries: entries, onAnswerToggle: (index, value) {}));*/
      },
    ),
  );
  return res;
}

/// Закреплённая колонка с оглавлением для широкого экрана — тот же список, что
/// и во всплывающем оглавлении, но всегда на виду (как в конспектах).
class _ZakonToc extends StatelessWidget {
  const _ZakonToc({
    required this.paragraphs,
    required this.isSerbian,
    required this.onSelected,
  });

  final List<BezbParagraph> paragraphs;
  final bool isSerbian;
  final void Function(BezbParagraph paragraph) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = zakonTableOfContents(paragraphs);
    return SizedBox(
      width: _kTocWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              LocaleKeys.zakon_contents.tr().toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              itemBuilder: (context, index) => _TableOfContentsItem(
                paragraphs: list[index],
                isSerbian: isSerbian,
                dense: true,
                onSelected: onSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableOfContentsItem extends StatelessWidget {
  const _TableOfContentsItem({
    required this.paragraphs,
    required this.isSerbian,
    required this.onSelected,
    this.dense = false,
  });

  final List<BezbParagraph> paragraphs;
  final bool isSerbian;
  final void Function(BezbParagraph paragraph) onSelected;

  /// Оглавление показано в узкой боковой колонке: заголовки мельче, кнопки
  /// членов плотнее — иначе список глав не помещается по ширине.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (paragraphs.isNotEmpty && !paragraphs.first.isChlan) {
      final paragraph = paragraphs.first;
      String text = isSerbian
          ? (paragraph.sr ?? '')
          : (paragraph.ru ?? paragraph.sr ?? '');

      final TextStyle? style;
      if (dense) {
        style = paragraph.isTitle ? textTheme.labelLarge : textTheme.titleSmall;
      } else {
        style = paragraph.isTitle
            ? textTheme.titleMedium
            : textTheme.titleLarge;
      }

      return InkWell(
        onTap: () => onSelected(paragraph),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text.fixMd,
            // textAlign: TextAlign.center,
            style: style,
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Wrap(
          spacing: dense ? 4 : 0,
          children: paragraphs.map((e) {
            var text = Text(
              (isSerbian ? (e.sr ?? '') : (e.ru ?? e.sr ?? '')).fixMd,
              style: dense ? textTheme.bodySmall : null,
            );

            return TextButton(
              style: dense
                  ? TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : null,
              onPressed: () {
                onSelected(e);
              },
              child: text,
            );
          }).toList(),
        ),
      );
    }
  }
}

extension _FixChlan on String {
  String get fixMd => replaceAll('*', '')
      .replaceAll('<sup>', '')
      .replaceAll('</sup>', '')
      .replaceAll('\\', '')
      .replaceAll('_', '')
      .trim();
}
