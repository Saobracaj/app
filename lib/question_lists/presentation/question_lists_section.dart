import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/presentation/wide_layout.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../domain/list_style.dart';
import '../models/question_list.dart';
import '../state_management/question_lists_bloc.dart';
import '../state_management/question_lists_events.dart';
import '../state_management/question_lists_state.dart';
import 'list_editor_dialog.dart';

/// The "question lists" block of the home screen: a horizontally scrolling row
/// of small cards — the automatic lists first, then the user's custom ones, and
/// finally a "create list" card.
///
/// Feature flags:
///   * `auto_question_lists` — shows the automatic lists;
///   * `custom_question_lists` — shows the "create list" card. When it is off
///     (e.g. premium expired) the custom lists the user already made stay
///     visible and readable, they just cannot be created or edited any more.
///
/// With both flags off the whole block disappears.
class QuestionListsSection extends StatelessWidget {
  const QuestionListsSection({super.key, this.wide = false});

  /// Раскладка широкого экрана: вместо горизонтальной ленты — плиточная сетка
  /// во всю ширину колонки контента (макет веб-версии).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagsBloc>().state;
    final autoEnabled = flags.isEnabled(AppFeature.autoQuestionLists);
    final customEnabled = flags.isEnabled(AppFeature.customQuestionLists);
    if (!autoEnabled && !customEnabled) return const SizedBox.shrink();

    // Ленивый расчёт автосписков, которым нужен бэкенд («личные слабые места»):
    // снапшот сложности запрашивается только сейчас, когда блок появился на
    // экране, а не на старте приложения. Bloc грузит его один раз, поэтому
    // событие безопасно слать из build.
    if (autoEnabled) {
      context.read<QuestionListsBloc>().add(AutoListsRequested());
    }

    return BlocBuilder<QuestionListsBloc, QuestionListsState>(
      builder: (context, state) {
        final lists = [
          if (autoEnabled) ...state.autoLists,
          ...state.customLists,
        ];
        if (lists.isEmpty && !customEnabled) return const SizedBox.shrink();

        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(
                title: LocaleKeys.questionLists_section.tr(),
                hint: LocaleKeys.questionLists_listsCount.tr(
                  args: ['${lists.length}'],
                ),
                action: customEnabled
                    ? TextButton(
                        onPressed: () => _createList(context),
                        child: Text(LocaleKeys.questionLists_create.tr()),
                      )
                    : null,
              ),
              ResponsiveGrid(
                minItemWidth: 176,
                children: [
                  for (final list in lists)
                    QuestionListChip(
                      list: list,
                      expand: true,
                      onTap: () => Routemaster.of(
                        context,
                      ).push('/lists/${Uri.encodeComponent(list.id)}'),
                    ),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                LocaleKeys.questionLists_section.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // Плитки в ленте выравниваются по самой высокой: у списка с
              // названием в две строки карточка выше, и без растягивания ряд
              // выглядел бы рваным (в макете плитки — flex-строка).
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final list in lists)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: QuestionListChip(
                          list: list,
                          onTap: () => Routemaster.of(
                            context,
                          ).push('/lists/${Uri.encodeComponent(list.id)}'),
                        ),
                      ),
                    if (customEnabled)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: _CreateListChip(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Открывает диалог создания списка и заводит список, если пользователь его
/// подтвердил. Точка входа одна и та же и у карточки-ленты, и у ссылки
/// «Создать список» в заголовке блока на широком экране.
Future<void> _createList(BuildContext context) async {
  final bloc = context.read<QuestionListsBloc>();
  final draft = await showListEditorDialog(context);
  if (draft == null) return;
  bloc.add(QuestionListCreated(name: draft.name, color: draft.color));
}

/// Одна плитка списка по карточке дизайн-системы «Списки вопросов»:
/// иконка-тайл сверху, под ней название и счётчик вопросов.
class QuestionListChip extends StatelessWidget {
  const QuestionListChip({
    super.key,
    required this.list,
    this.onTap,
    this.expand = false,
  });

  final QuestionList list;
  final VoidCallback? onTap;

  /// В сетке широкого экрана карточка занимает всю ячейку, а не фиксированные
  /// [kListCardWidth] логических пикселей ленты.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material с InkWell внутри, а не InkWell поверх непрозрачного Container:
    // иначе hover-подсветка рисуется под карточкой и не видна.
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kListCardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: expand ? null : kListCardWidth,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              QuestionListAvatar(list: list),
              const SizedBox(height: 8),
              Text(
                list.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              Text(
                LocaleKeys.questionLists_questionsPlural.plural(
                  list.questionIds.length,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ширина плитки в горизонтальной ленте (`flex:0 0 150px` в макете).
const double kListCardWidth = 150;

/// Скругление плитки списка (`border-radius:18px`).
const double kListCardRadius = 18;

/// Иконка-тайл списка: скруглённый квадрат в цвете списка с иконкой в парном
/// on-цвете (см. [QuestionListX.avatarColors]).
class QuestionListAvatar extends StatelessWidget {
  const QuestionListAvatar({super.key, required this.list, this.size = 30});

  final QuestionList list;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = list.icon;
    final colors = list.avatarColors(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.background,
        // Пропорция макета: тайл 30×30 со скруглением 10.
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: icon == null
          ? null
          : Icon(icon, size: size * 0.55, color: colors.foreground),
    );
  }
}

/// The trailing "create list" card. Only rendered while
/// `custom_question_lists` is on.
class _CreateListChip extends StatelessWidget {
  const _CreateListChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kListCardRadius),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _createList(context),
        child: Container(
          width: kListCardWidth,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.questionLists_create.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
