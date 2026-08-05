import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../../models/models.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../../questions/state_management/all_questions_bloc.dart';
import '../../theme/quiz_colors.dart';
import '../models/group_event.dart';
import '../state_management/group_feed_bloc.dart';
import '../state_management/group_feed_events.dart';
import '../state_management/group_feed_state.dart';
import 'group_event_summary.dart';

/// Everything that has happened in a group, newest first.
///
/// The list grows in both directions: pages of history load as the reader
/// scrolls down, and new events arrive over the subscription while the screen is
/// open (the requirement is that an open feed refreshes itself). Both go through
/// [GroupFeedBloc], which owns the ordering.
///
/// Every line is built here from the event's structured payload — the server
/// sends no ready-made sentences, because the reader may be reading in any of
/// three languages.
class GroupFeedPage extends StatelessWidget {
  const GroupFeedPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<GroupFeedBloc>(param1: groupId)..add(const GroupFeedOpened()),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupFeedBloc, GroupFeedState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        context.read<GroupFeedBloc>().add(const GroupFeedErrorShown());
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.groupName.isEmpty
                  ? LocaleKeys.groups_feed_title.tr()
                  : state.groupName,
            ),
            actions: [
              // Honest about the live connection: when it is down the list is
              // still readable, it just stops updating by itself.
              if (state.loaded && !state.live)
                IconButton(
                  tooltip: LocaleKeys.groups_feed_offline.tr(),
                  onPressed: () => context.read<GroupFeedBloc>().add(
                    const GroupFeedRefreshed(),
                  ),
                  icon: const Icon(Icons.cloud_off_outlined),
                ),
            ],
            bottom: state.loading && state.loaded
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: RefreshIndicator(
            onRefresh: () async =>
                context.read<GroupFeedBloc>().add(const GroupFeedRefreshed()),
            child: switch ((state.loaded, state.isEmpty)) {
              (false, _) => const Center(child: CircularProgressIndicator()),
              (_, true) => _EmptyFeed(),
              _ => _FeedList(state: state),
            },
          ),
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
  const _FeedList({required this.state});

  final GroupFeedState state;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // Ask for the next page a screenful before the end, so scrolling does not
      // stop to wait for it.
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (state.hasMore &&
            !state.loadingMore &&
            metrics.axis == Axis.vertical &&
            metrics.pixels > metrics.maxScrollExtent - 400) {
          context.read<GroupFeedBloc>().add(const GroupFeedMoreRequested());
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.events.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= state.events.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return GroupFeedTile(event: state.events[index]);
        },
      ),
    );
  }
}

/// One event. What it shows depends on the kind: a block result carries its
/// score and a colour, an exam attempt carries its points and the questions that
/// went wrong, everything else is a single sentence.
class GroupFeedTile extends StatelessWidget {
  const GroupFeedTile({super.key, required this.event});

  final GroupEvent event;

  @override
  Widget build(BuildContext context) {
    return switch (event.kind) {
      GroupEventKind.subcategoryCompleted when event.subcategory != null =>
        _SubcategoryTile(event: event, details: event.subcategory!),
      GroupEventKind.practiceFinished when event.practice != null =>
        _PracticeTile(event: event, details: event.practice!),
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
      leading: Icon(_icon, color: Theme.of(context).colorScheme.outline),
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
  const _SubcategoryTile({required this.event, required this.details});

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
      title: Text(
        LocaleKeys.groups_feed_subcategoryTitle.tr(
          args: [
            event.actor.displayName,
            subcategoryTitle(context, details.subcategory),
          ],
        ),
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
      onTap: questions.isEmpty
          ? null
          : () => Routemaster.of(context).push(
              '/start?q=${questions.join(',')}'
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
  const _PracticeTile({required this.event, required this.details});

  final GroupEvent event;
  final PracticeFinishedDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    final wrong = _knownQuestions(context, details.wrongAnswers);
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(
        details.passed ? Icons.verified_outlined : Icons.error_outline,
        color: details.passed ? quiz.correct : quiz.wrong,
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
                .tr(args: ['${details.points}']),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: details.passed ? quiz.correct : quiz.wrong,
            ),
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
          for (final question in wrong)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  question.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          if (wrong.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Routemaster.of(context).push(
                  '/start?q=${wrong.map((q) => q.id).join(',')}',
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
