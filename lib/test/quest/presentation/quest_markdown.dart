import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/markdown/phrase_highlight.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/dictionary/dictionary.dart';
import 'package:saobracaj/theme/quiz_colors.dart';
import 'package:saobracaj/zakon/presentation/zakon_panel.dart';
import 'package:saobracaj/test/animations/animations_map.dart';
import 'package:saobracaj/util/nav_to_url.dart';

class QuestMarkdown extends StatelessWidget {
  const QuestMarkdown({
    super.key,
    required this.text,
    this.padding,
    this.useLargeText = true,
    this.pStyle,
    this.highlights = const [],
  });

  final String text;
  final EdgeInsets? padding;
  final bool useLargeText;

  /// Phrases to draw with a highlighter background — the key-phrase cues of a
  /// revealed question. Matched by whole words, case-insensitive; see
  /// [markPhrases].
  final List<PhraseHighlight> highlights;

  /// Overrides the paragraph style. Markdown ignores [DefaultTextStyle], so
  /// this is the only way a host (e.g. a highlighted answer card) can tint the
  /// body text. Takes precedence over [useLargeText].
  final TextStyle? pStyle;

  @override
  Widget build(BuildContext context) {
    // Highlights ride on the `~~…~~` (strikethrough) syntax: it is the one
    // inline span the style sheet lets us restyle freely, it nests dictionary
    // links, and none of the texts shown with highlights (question and answer
    // wordings) use strikethrough for its own meaning. The `del` slot is
    // therefore turned into a marker background — only when there is
    // something to mark, so ordinary markdown elsewhere is untouched.
    final marked = highlights.isEmpty ? text : markPhrases(text, highlights);
    return Markdown(
      shrinkWrap: true,
      selectable: false,
      physics: NeverScrollableScrollPhysics(),
      data: marked,
      onTapLink: (text, href, title) => openDictionary(context, href),
      padding: padding ?? EdgeInsets.zero,
      styleSheet: MarkdownStyleSheet(
        p:
            pStyle ??
            (useLargeText ? Theme.of(context).textTheme.bodyLarge : null),
        a: TextStyle(color: Theme.of(context).colorScheme.primary),
        del: highlights.isEmpty
            ? null
            : TextStyle(
                backgroundColor: Theme.of(context).quiz.highlight,
                decoration: TextDecoration.none,
              ),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withAlpha(40),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
      sizedImageBuilder: (config) {
        final uri = config.uri.toString();

        final Widget imageWidget;
        if (uri.toString().startsWith('anim/')) {
          final animationName = uri.split('anim/')[1];
          imageWidget = getAnimation(animationName);
        } else if (uri.startsWith('http')) {
          imageWidget = Image.network(uri);
        } else {
          imageWidget = Image.asset('assets/md_img/$uri');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            if (config.title != null)
              Text(
                config.title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            SizedBox(height: 8),
            imageWidget,
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void openDictionary(BuildContext context, String? href) async {
    if (href == null) return;
    if (href.startsWith('dict/')) {
      final link = href.split('/')[1];

      showMarkdown(context, Uri.decodeFull(link));
    } else if (href.startsWith('/zakon') || href.startsWith('/pravilnik')) {
      final link = href.split('/')[1];
      openZakon(context, link);
    } else if (href.startsWith('zakon') || href.startsWith('pravilnik')) {
      // `pravilnik?chapter=…&chlan=…&paragraph=…` — та же ссылка, что и на
      // закон, только в правилник о саобраћајној сигнализацији: объяснения к
      // вопросам о знаках и разметке ссылаются именно туда.
      openZakon(context, href);
    } else {
      // Ссылка на наш сайт открывается внутри приложения — этим занимается
      // navigateToUri, в браузер уходят только чужие адреса.
      navigateToUri(context, Uri.parse(href));
    }
  }
}

Future showMarkdown(BuildContext context, String link) async {
  final o = getDictByTitle(link);
  if (o == null) return;
  analytics.logDefinitionOpened(term: link);
  final String text = o['sr'];
  // Русский перевод определения показываем только тем, кто выбрал
  // русскоязычный контент (в стартовом вопросе или потом в настройках) —
  // остальным карточка дублировала одно и то же на двух языках. Словарь
  // терминов лежит в бандле и бесплатен для всех, поэтому смотрим на сам выбор
  // пользователя, а не на премиум-грант.
  final ruText = context.read<FeatureFlagsBloc>().state.russianContentChosen
      ? o['ru'] as String?
      : null;

  final paragraph = o['paragraph'];
  final chlan = o['chlan'];
  final chapter = o['chapter'];

  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        // Для того чтобы bottom sheet не обрезался под клавиатурой
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ((o['title'] as String?)?.capitalize() ?? '').fixMd,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SizedBox(height: 16),
              // Строка-ссылка на статью закона. ListTile разводил иконку и
              // подпись по разным «этажам» (иконка по центру строки, текст —
              // в слоте subtitle), поэтому здесь обычный Row: иконка и текст
              // выровнены по своим базовым линиям.
              InkWell(
                onTap: () => openZakon(
                  context,
                  'zakon?paragraph=$paragraph&chlan=$chlan&chapter=$chapter',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Закон о безбедности саобраћаја на путевима, '
                          'члан $chlan',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              QuestMarkdown(
                text: text.fixMd,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              if (ruText != null) ...[
                SizedBox(height: 16),
                QuestMarkdown(
                  text: ruText.fixMd,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ],

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Back'),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
  return res;
}

extension _FixChlan on String {
  String get fixMd => replaceAll('<sup>', '').replaceAll('</sup>', '').trim();
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
