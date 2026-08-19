import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/presentation/load_failed.dart';
import '../../core/presentation/pagination.dart';
import '../../generated/locale_keys.g.dart';
import '../../models/models.dart';
import '../../core/presentation/relative_time.dart';
import '../../questions/state_management/all_questions_bloc.dart';
import '../../test/practice/practice.dart' show formatDuration;
import '../../test/quest/preview/question_preview_sheet.dart';
import '../../theme/quiz_colors.dart';
import '../models/group_event.dart';
import '../state_management/group_feed_bloc.dart';
import '../state_management/group_feed_events.dart';
import '../state_management/group_feed_state.dart';
import 'group_event_summary.dart';

/// Вкладка «События» экрана группы: всё, что в ней произошло.
///
/// Шапка, вкладки и переключение на разговор — дело [GroupPage]; здесь только
/// список. [GroupFeedBloc] тоже живёт там, над вкладками: невидимую вкладку
/// PageView сносит с дерева, и лента перечитывалась бы при каждом
/// переключении.
///
/// Список растёт в обе стороны: страницы истории подгружаются при прокрутке
/// вниз, а новые события приезжают по подписке, пока экран открыт (открытая
/// лента обязана обновляться сама). И то и другое — через [GroupFeedBloc],
/// который владеет порядком.
///
/// Каждая строка собирается здесь из структурированных полей события: готовых
/// предложений сервер не присылает, потому что читать могут на любом из трёх
/// языков.
class GroupFeedPage extends StatelessWidget {
  const GroupFeedPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    // Ошибки чтения ленты не всплывают снек-баром: их место — прямо в списке
    // (кнопка «повторить») и значок «нет связи» в шапке.
    return BlocBuilder<GroupFeedBloc, GroupFeedState>(
      builder: (context, state) {
        return Column(
          children: [
            // Роль полосы под AppBar: она общая с вкладкой чата, поэтому
            // индикатор обновления рисуется внутри вкладки.
            if (state.loading && state.loaded)
              const LinearProgressIndicator(minHeight: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => context.read<GroupFeedBloc>().add(
                  const GroupFeedRefreshed(),
                ),
                child: switch ((state.loaded, state.failed, state.isEmpty)) {
                  // Первая страница не пришла и не придёт сама: индикатор врал
                  // бы бесконечно, а «событий пока нет» — просто врал.
                  (false, true, _) => LoadFailedList(
                    message: state.failedOffline
                        ? LocaleKeys.groups_feed_offline.tr()
                        : LocaleKeys.network_loadFailed.tr(),
                    onRetry: () => context.read<GroupFeedBloc>().add(
                      const GroupFeedRefreshed(),
                    ),
                  ),
                  (false, _, _) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  (_, _, true) => _EmptyFeed(),
                  _ => _FeedList(groupId: groupId, state: state),
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A group where nothing has happened yet. Scrollable so pull-to-refresh still
/// works on it.
class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Text(
            LocaleKeys.groups_noEvents.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.groupId, required this.state});

  final String groupId;
  final GroupFeedState state;

  @override
  Widget build(BuildContext context) {
    // Что показывать, решено ещё в блоке: список на экране и список, по
    // которому считается пагинация, должны быть одним и тем же списком.
    final events = state.events;
    void loadMore() =>
        context.read<GroupFeedBloc>().add(const GroupFeedMoreRequested());
    return PaginationTrigger(
      enabled: state.hasMore && !state.loadingMore && !state.loading,
      onLoadMore: loadMore,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: events.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= events.length) {
            return LoadMoreFooter(
              loading: state.loadingMore,
              onLoadMore: loadMore,
            );
          }
          return GroupFeedTile(groupId: groupId, event: events[index]);
        },
      ),
    );
  }
}

/// One event. What it shows depends on the kind: a block result carries its
/// score and a colour, an exam attempt carries its points and the questions that
/// went wrong, everything else is a single sentence.
class GroupFeedTile extends StatelessWidget {
  const GroupFeedTile({super.key, required this.groupId, required this.event});

  /// Группа, чья это лента: вопросы события открываются её адресом — см.
  /// [_SubcategoryTile].
  final String groupId;
  final GroupEvent event;

  @override
  Widget build(BuildContext context) {
    return switch (event.kind) {
      GroupEventKind.subcategoryCompleted when event.subcategory != null =>
        _SubcategoryTile(
          groupId: groupId,
          event: event,
          details: event.subcategory!,
        ),
      GroupEventKind.practiceFinished when event.practice != null =>
        _PracticeTile(
          groupId: groupId,
          event: event,
          details: event.practice!,
        ),
      _ => _SimpleTile(event: event),
    };
  }
}

/// Membership changes, renames and achievements: an icon, a sentence, a time.
class _SimpleTile extends StatelessWidget {
  const _SimpleTile({required this.event});

  final GroupEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _LeadingBox(
        child: Icon(_icon, color: Theme.of(context).colorScheme.outline),
      ),
      title: Text(groupEventSummary(context, event)),
      subtitle: _EventTime(event.occurredAt),
    );
  }

  IconData get _icon => switch (event.kind) {
    GroupEventKind.memberJoined => Icons.person_add_outlined,
    GroupEventKind.memberRemoved => Icons.person_remove_outlined,
    GroupEventKind.memberLeft => Icons.logout,
    GroupEventKind.ownerChanged => Icons.workspace_premium_outlined,
    GroupEventKind.groupRenamed => Icons.drive_file_rename_outline,
    GroupEventKind.achievementUnlocked => Icons.emoji_events_outlined,
    _ => Icons.circle_outlined,
  };
}

/// A finished block of questions: who, which block, how many right, and whether
/// that is better or worse than their last attempt at it. Tapping it opens the
/// block.
class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.groupId,
    required this.event,
    required this.details,
  });

  final String groupId;
  final GroupEvent event;
  final SubcategoryCompletedDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _subcategoryQuestions(context, details.subcategory);
    return ListTile(
      leading: _ScoreBadge(
        right: details.rightAnswers,
        all: details.allAnswers,
      ),
      // Имя участника и рядом чип с усечённым названием блока — целиком
      // название видно на экране блока, здесь оно только загромождало строку.
      title: Row(
        children: [
          Flexible(
            child: Text(
              event.actor.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _BlockChip(label: subcategoryTitle(context, details.subcategory)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.groups_feed_score.tr(
              args: ['${details.rightAnswers}', '${details.allAnswers}'],
            ),
          ),
          if (_deltaLine(details) case final line?)
            Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(
                color: details.delta == ResultDelta.improved
                    ? theme.quiz.correct
                    : theme.quiz.wrong,
              ),
            ),
          _EventTime(event.occurredAt),
        ],
      ),
      trailing: questions.isEmpty
          ? null
          : const Icon(Icons.chevron_right, size: 20),
      // Полный путь, а не относительный: лента живёт вкладкой по адресу
      // '/groups/:id/feed/events', и относительное 'q' открыло бы вопросы
      // внутри вкладки, под её же шапкой. '/groups/:id/feed/q' лежит над
      // экраном группы, так что «назад» (и завершение прохождения) возвращает
      // в ленту, а не на главную.
      onTap: questions.isEmpty
          ? null
          : () => Routemaster.of(context).push(
              '/groups/$groupId/feed/q?q=${questions.join(',')}'
              '&subcategory=${details.subcategory}',
            ),
    );
  }

  /// "Better than last time (12 of 20)" — only when the server compared this
  /// result with a previous one.
  String? _deltaLine(SubcategoryCompletedDetails details) {
    final previousRight = details.previousRightAnswers;
    final previousAll = details.previousAllAnswers;
    return switch (details.delta) {
      ResultDelta.improved => LocaleKeys.groups_feed_improved.tr(
        args: ['${previousRight ?? 0}', '${previousAll ?? 0}'],
      ),
      ResultDelta.worsened => LocaleKeys.groups_feed_worsened.tr(
        args: ['${previousRight ?? 0}', '${previousAll ?? 0}'],
      ),
      _ => null,
    };
  }
}

/// An exam simulation: the score, pass or fail, and the questions the person
/// stumbled on — expandable, and openable as a practice run.
class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.groupId,
    required this.event,
    required this.details,
  });

  final String groupId;
  final GroupEvent event;
  final PracticeFinishedDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    final wrong = _knownQuestions(context, details.wrongAnswers);
    // Максимум за прогон нет в событии — он восстанавливается как набранные
    // баллы плюс стоимость вопросов с ошибками (в экзамене вопрос либо
    // засчитан целиком, либо нет).
    final maxPoints =
        details.points + wrong.fold<int>(0, (sum, q) => sum + q.points);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: _LeadingBox(
        child: Icon(
          details.passed ? Icons.verified_outlined : Icons.error_outline,
          color: details.passed ? quiz.correct : quiz.wrong,
        ),
      ),
      title: Text(
        LocaleKeys.groups_feed_practiceTitle.tr(
          args: [event.actor.displayName],
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (details.passed
                    ? LocaleKeys.groups_feed_practicePassed
                    : LocaleKeys.groups_feed_practiceFailed)
                .tr(args: ['${details.points}', '$maxPoints']),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: details.passed ? quiz.correct : quiz.wrong,
            ),
          ),
          // Сколько времени заняла симуляция. Событий, записанных до того, как
          // сервер стал хранить длительность, это не касается — там её нет.
          if (details.durationSeconds != null)
            Text(
              LocaleKeys.groups_feed_practiceDuration.tr(
                args: [
                  formatDuration(Duration(seconds: details.durationSeconds!)),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          _EventTime(event.occurredAt),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (details.wrongAnswers.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              LocaleKeys.groups_feed_noMistakes.tr(),
              style: theme.textTheme.bodySmall,
            ),
          )
        else ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              LocaleKeys.groups_feed_mistakes.tr(
                args: ['${details.wrongAnswers.length}'],
              ),
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 4),
          // Только номера вопросов; чип открывает тот же bottom sheet
          // предпросмотра, что и ссылки на вопросы в конспекте.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in details.wrongAnswers)
                  ActionChip(
                    label: Text('$id'),
                    labelStyle: theme.textTheme.labelMedium,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showQuestionPreview(context, id),
                  ),
              ],
            ),
          ),
          if (wrong.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                // Полный путь — см. комментарий в _SubcategoryTile.
                onPressed: () => Routemaster.of(context).push(
                  '/groups/$groupId/feed/q'
                  '?q=${wrong.map((q) => q.id).join(',')}',
                ),
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(LocaleKeys.groups_feed_openMistakes.tr()),
              ),
            ),
        ],
      ],
    );
  }
}

/// Одинаковая по размеру область слева у всех событий — как у [_ScoreBadge]
/// (44×44), иначе иконки «уже» бейджа и текст в ленте прыгает по горизонтали.
class _LeadingBox extends StatelessWidget {
  const _LeadingBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 44, height: 44, child: Center(child: child));
  }
}

/// Чип с усечённым названием блока в заголовке события.
class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The score of a finished block, coloured on the same scale as the little
/// charts under the categories on the home screen.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.right, required this.all});

  final int right;
  final int all;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = scoreColors(context, right, all);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$right/$all',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}

class _EventTime extends StatelessWidget {
  const _EventTime(this.time);

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      relativeTime(time),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

/// Fill and label colour for a result, mirroring `MiniChart.barColors`: all
/// right is "correct", nearly all is "warning", less than half is "wrong".
(Color, Color) scoreColors(BuildContext context, int right, int all) {
  final quiz = Theme.of(context).quiz;
  if (all <= 0) return (quiz.info, quiz.onInfo);
  if (right >= all) return (quiz.correct, quiz.onCorrect);
  final ratio = right / all;
  if (ratio > 0.9) return (quiz.warning, quiz.onWarning);
  if (ratio < 0.5) return (quiz.wrong, quiz.onWrong);
  return (quiz.info, quiz.onInfo);
}

/// The ids of every question in a subcategory, so the block can be opened from
/// the feed. Empty while the question data is still loading.
List<int> _subcategoryQuestions(BuildContext context, String subcategoryId) {
  final data = context.read<AllQuestionsBloc>().state.questionsData;
  final id = int.tryParse(subcategoryId);
  if (data == null || id == null) return const [];
  return [
    for (final question in data.questions)
      if (question.subcategoryId == id) question.id,
  ];
}

/// The questions behind a list of ids, skipping any this build does not know.
List<Question> _knownQuestions(BuildContext context, List<int> ids) {
  final data = context.read<AllQuestionsBloc>().state.questionsData;
  if (data == null) return const [];
  final wanted = ids.toSet();
  return [
    for (final question in data.questions)
      if (wanted.contains(question.id)) question,
  ];
}
