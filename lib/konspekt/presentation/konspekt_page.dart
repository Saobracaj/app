import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/deep_links.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/presentation/load_failed_view.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/presentation/feature_gate.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_inline_text.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_markdown.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_events.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_state.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_source.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_target.dart';
import 'package:saobracaj/question_feedback/presentation/report_problem_button.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Viewer for a category konspekt (study notes). Each section is rendered as
/// its own list item and is deep-linkable as
/// `/konspekt?category=<id>&section=<slug>`.
class KonspektPage extends StatefulWidget {
  const KonspektPage({super.key, required this.categoryId, this.section});

  final String categoryId;
  final String? section;

  @override
  State<KonspektPage> createState() => _KonspektPageState();
}

class _KonspektPageState extends State<KonspektPage> {
  final ItemScrollController _itemScrollController = ItemScrollController();

  @override
  Widget build(BuildContext context) {
    // The notes are premium content and reachable by deep link, so the page
    // itself checks the flag: with it off nothing is fetched at all (the
    // backend would refuse the query anyway).
    return FeatureGate(
      feature: AppFeature.categorySummaries,
      categoryId: widget.categoryId,
      placeholder: const _UnavailablePage(),
      child: _content(),
    );
  }

  Widget _content() {
    return BlocProvider(
      create: (_) => getIt<KonspektBloc>(
        param1: widget.categoryId,
        param2: widget.section,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<KonspektBloc, KonspektState>(
            builder: (context, state) {
              final russian = context
                  .watch<FeatureFlagsBloc>()
                  .state
                  .russianContentForCategory(widget.categoryId);
              return Text(
                state.konspekt?.categoryName.select(russian: russian) ??
                    LocaleKeys.konspekt_title.tr(),
              );
            },
          ),
          actions: [
            // Конспект длинный, кнопка в его хвосте невидима — поэтому жалоба
            // живёт в шапке и доступна с любого места текста.
            FeatureGate(
              feature: AppFeature.questionFeedback,
              child: Builder(
                builder: (context) => IconButton(
                  tooltip: LocaleKeys.questionFeedback_report.tr(),
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => showQuestionFeedbackDialog(
                    context,
                    target: QuestionFeedbackTarget.konspekt(widget.categoryId),
                    source: QuestionFeedbackSource.konspekt,
                  ),
                ),
              ),
            ),
            FeatureGate(
              feature: AppFeature.russianContent,
              categoryId: widget.categoryId,
              child: BlocBuilder<KonspektBloc, KonspektState>(
                builder: (context, state) {
                  final dictionary = state.konspekt?.dictionary;
                  if (dictionary == null) return const SizedBox.shrink();
                  return IconButton(
                    tooltip: LocaleKeys.konspekt_dictionary.tr(),
                    icon: const Icon(Icons.translate_outlined),
                    onPressed: () => _showDictionary(context, dictionary),
                  );
                },
              ),
            ),
          ],
        ),
        body: BlocConsumer<KonspektBloc, KonspektState>(
          listener: (context, state) {
            final scrollTo = state.scrollTo;
            if (scrollTo != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _itemScrollController.scrollTo(
                  index: scrollTo,
                  duration: const Duration(milliseconds: 300),
                  alignment: 0.0,
                );
              });
            }
          },
          builder: (context, state) {
            if (state.errorMessage != null) {
              if (state.retryable) {
                // No network / server error: offer a retry (and the Bloc
                // reloads by itself once the connection is back).
                return LoadFailedView(
                  offline: state.offline,
                  message: state.errorMessage,
                  onRetry: () =>
                      context.read<KonspektBloc>().add(KonspektStarted()),
                );
              }
              return Center(
                child: Text(
                  state.errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }
            final konspekt = state.konspekt;
            if (state.inProgress || konspekt == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final russian = context
                .watch<FeatureFlagsBloc>()
                .state
                .russianContentForCategory(widget.categoryId);
            // Markdown конспекта на всю ширину окна нечитаем — колонка
            // ограничена шириной комфортного чтения.
            final article = ReadableWidth(
              child: ScrollablePositionedList.builder(
                itemCount: state.itemCount,
                itemScrollController: _itemScrollController,
                itemBuilder: (context, index) {
                  if (state.hasIntro && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: KonspektMarkdown(
                        text: konspekt.intro!.select(russian: russian),
                        categoryId: konspekt.categoryId,
                        onSectionLink: (sectionId) => context
                            .read<KonspektBloc>()
                            .add(KonspektSectionRequested(sectionId)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    );
                  }
                  final section =
                      konspekt.sections[index - (state.hasIntro ? 1 : 0)];
                  final isLast = index == state.itemCount - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 32 : 0),
                    child: _SectionItem(
                      section: section,
                      russian: russian,
                      categoryId: konspekt.categoryId,
                      onSectionLink: (sectionId) => context
                          .read<KonspektBloc>()
                          .add(KonspektSectionRequested(sectionId)),
                    ),
                  );
                },
              ),
            );
            // Широкий экран: слева закреплённое содержание, справа — текст
            // (макет веб-версии).
            if (!context.isExpandedScreen) return article;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KonspektToc(
                  konspekt: konspekt,
                  russian: russian,
                  onSelected: (sectionId) => context.read<KonspektBloc>().add(
                    KonspektSectionRequested(sectionId),
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

/// Содержание конспекта — закреплённая колонка со ссылками на разделы.
class _KonspektToc extends StatelessWidget {
  const _KonspektToc({
    required this.konspekt,
    required this.russian,
    required this.onSelected,
  });

  final Konspekt konspekt;
  final bool russian;
  final void Function(String sectionId) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(
              LocaleKeys.konspekt_contents.tr().toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final section in konspekt.sections)
            InkWell(
              onTap: () => onSelected(section.id),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: KonspektInlineText(
                  text: section.title.select(russian: russian),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a user without the `category_summaries` entitlement sees when they open
/// a konspekt link.
class _UnavailablePage extends StatelessWidget {
  const _UnavailablePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.konspekt_title.tr())),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            LocaleKeys.konspekt_unavailable.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _SectionItem extends StatelessWidget {
  const _SectionItem({
    required this.section,
    required this.russian,
    required this.categoryId,
    required this.onSectionLink,
  });

  final KonspektSection section;

  /// Whether the study content is shown in Russian (`russian_content` on).
  final bool russian;

  final String categoryId;
  final void Function(String sectionId) onSectionLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: KonspektInlineText(
                  text: section.title.select(russian: russian),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: LocaleKeys.konspekt_copyLink.tr(),
                icon: Icon(
                  Icons.link,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                onPressed: () => _copyLink(context),
              ),
            ],
          ),
        ),
        KonspektMarkdown(
          text: section.content.select(russian: russian),
          categoryId: categoryId,
          onSectionLink: onSectionLink,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ],
    );
  }

  void _copyLink(BuildContext context) {
    final uri = appLink('/konspekt', {
      'category': categoryId,
      'section': section.id,
    });
    Clipboard.setData(ClipboardData(text: uri.toString())).then((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.konspekt_linkCopied.tr())),
      );
    });
  }
}

// Словарь — глоссарий сербских экзаменационных терминов с русским переводом,
// то есть контент по природе русскоязычный: кнопка гейтится russian_content,
// поэтому здесь остаётся RU-first `.text` без выбора языка.
Future<void> _showDictionary(
  BuildContext context,
  KonspektDictionary dictionary,
) {
  return showModalBottomSheet(
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
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            KonspektInlineText(
              text: dictionary.title.text,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            KonspektMarkdown(text: dictionary.content.text),
          ],
        );
      },
    ),
  );
}
