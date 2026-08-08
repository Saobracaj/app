import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/selection_limit_feedback.dart';
import 'package:saobracaj/dictionary/dictionary.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';
import 'package:saobracaj/test/quest/presentation/question_image_card.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/quest/state_management/quest_content_bloc.dart';
import 'package:saobracaj/test/state_management/start_test_bloc.dart';

/// Shows question [questionId] in a bottom sheet: the question exactly as it is
/// asked — photo, statement, answers — and nothing else. No tabs, no law links,
/// no run around it.
///
/// This is how a question referenced from a konspekt (and, later, from the
/// other content sections) opens: from inside a text you want to check the
/// question and go back, not to be moved to another screen. "Развернуть" is
/// there for when you do want the full screen.
Future<void> showQuestionPreview(BuildContext context, int questionId) {
  // Root navigator: the tabs of the home screen each run their own navigator
  // inside the scaffold body, and a sheet pushed there would open *under* the
  // bottom navigation bar.
  return Navigator.of(context, rootNavigator: true).push(
    QuestionPreviewRoute(
      questionId: questionId,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// The route the preview lives on.
///
/// Deliberately a [PageRoute] rather than the usual `showModalBottomSheet`
/// (which is a [PopupRoute]): heroes only fly between two page routes, and the
/// photo flying into the full screen is the whole point of "Развернуть".
class QuestionPreviewRoute extends PageRouteBuilder<void> {
  QuestionPreviewRoute({required this.questionId, required String barrierLabel})
    : super(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        barrierLabel: barrierLabel,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            QuestionPreviewSheet(questionId: questionId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          );
        },
      );

  final int questionId;
}

/// The sheet itself. Reads the question out of [AllQuestionsBloc] (the quiz
/// ships with the app, so there is nothing to load) and drives the selection
/// with the same [QuestContentBloc] as the full screen.
class QuestionPreviewSheet extends StatelessWidget {
  const QuestionPreviewSheet({super.key, required this.questionId});

  final int questionId;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AllQuestionsBloc>().state.questionsData;
    final question = data?.questions.firstWhereOrNull(
      (q) => q.id == questionId,
    );
    final categoryName = question == null
        ? null
        : data?.categories
              .firstWhereOrNull((c) => c.id == question.categoryId)
              ?.name;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        // A sheet, not a screen: whatever it takes, but never the whole height —
        // and on wide windows never the whole width either, or the bottom sheet
        // degenerates into a full-width band.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          maxWidth: 640,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: question == null
                ? const _MissingQuestion()
                : BlocProvider(
                    create: (_) => QuestContentBloc(
                      {...question.choices},
                      const {},
                      question.id,
                    ),
                    child: _Content(
                      question: question,
                      categoryName: categoryName,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A question id that isn't in the bundled quiz (a typo in a konspekt link, or
/// a question dropped from the set). Nothing to show but a way out.
class _MissingQuestion extends StatelessWidget {
  const _MissingQuestion();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.quest_preview_notFound.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocaleKeys.quest_preview_close.tr()),
          ),
        ],
      ),
    );
  }
}

// Stateful only for the drag-to-dismiss accumulator below — everything else is
// still driven by the blocs.
class _Content extends StatefulWidget {
  const _Content({required this.question, this.categoryName});

  final Question question;
  final String? categoryName;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  Question get question => widget.question;

  /// Downward travel accumulated while the content is already at its top, so a
  /// continued pull closes the sheet — without this, the inner scroll view
  /// swallowed the drag and the sheet could only be dismissed from the header.
  double _pullDown = 0;
  bool _dismissing = false;

  static const _dismissThreshold = 48.0;

  bool _onScroll(ScrollNotification notification) {
    if (_dismissing || notification.depth != 0) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _pullDown = 0;
      return false;
    }

    final double delta;
    if (notification is OverscrollNotification) {
      if (notification.dragDetails == null) return false;
      delta = notification.overscroll;
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null) return false;
      // Only a pull past the top counts; ordinary scrolling resets the travel.
      if (notification.metrics.pixels > notification.metrics.minScrollExtent) {
        _pullDown = 0;
        return false;
      }
      delta = notification.scrollDelta ?? 0;
    } else {
      return false;
    }

    if (delta < 0) {
      _pullDown -= delta;
      if (_pullDown >= _dismissThreshold) {
        _dismissing = true;
        Navigator.of(context).pop();
      }
    } else if (delta > 0) {
      _pullDown = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rightAnswers = question.choices.where((c) => c.isCorrect).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dragging the handle (or anywhere in the header) throws the sheet away,
        // the gesture everyone tries first.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 250) {
              Navigator.of(context).pop();
            }
          },
          child: Column(
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.categoryName ??
                            LocaleKeys.quest_preview_title.tr(),
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      LocaleKeys.quest_points.plural(question.points),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SingleChildScrollView(
              // Bouncing physics so the pull past the top emits drag updates on
              // every platform (clamping physics reports them as overscrolls —
              // _onScroll handles both).
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 8),
              child: BlocConsumer<QuestContentBloc, QuesContentState>(
                listenWhen: (prev, curr) => prev.limitHits != curr.limitHits,
                listener: (context, state) => showSelectionLimitFeedback(
                  context,
                  LocaleKeys.quest_answerLimitReached.plural(rightAnswers),
                ),
                builder: (context, state) {
                  final bloc = context.read<QuestContentBloc>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (question.hasImage) ...[
                        QuestionImageCard(imageId: question.imageId),
                        const SizedBox(height: 14),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: QuestMarkdown(
                          text: question.text.trim().dict,
                          pStyle: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final choice in question.choices)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: AnswerOptionCard(
                            choice: choice,
                            selected: state.selectedChoices.contains(choice),
                            revealed: state.showCorrectAnswers,
                            showTranslation: false,
                            onTap: state.showCorrectAnswers
                                ? null
                                : () => bloc.add(AddChoice(choice)),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        _Actions(question: question),
      ],
    );
  }
}

/// Close / expand / answer.
///
/// The answer is only checked, never recorded: the preview is opened from a
/// text while reading it, not as an attempt inside a run, and there is no run
/// here to record it into.
class _Actions extends StatelessWidget {
  const _Actions({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuestContentBloc, QuesContentState>(
      builder: (context, state) {
        final canAnswer =
            !state.showCorrectAnswers && state.selectedChoices.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(LocaleKeys.quest_preview_close.tr()),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _expand(context, state),
                icon: const Icon(Icons.open_in_full, size: 18),
                label: Text(LocaleKeys.quest_preview_expand.tr()),
              ),
              if (canAnswer) ...[
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: () => _answer(context, state),
                  child: Text(LocaleKeys.quest_preview_answer.tr()),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Reveals the correct answers in place. A selection of the wrong size is
  /// refused the same way the full screen refuses it.
  void _answer(BuildContext context, QuesContentState state) {
    final correct = question.choices.where((c) => c.isCorrect).toSet();
    if (state.selectedChoices.length != correct.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.quest_wrongAnswerCount.tr())),
      );
      return;
    }
    context.read<QuestContentBloc>().add(ShowCorrectAnswers());
  }

  /// Opens the full question screen on top of the sheet — pushed imperatively
  /// so the photo can fly into it (see [QuestionPreviewRoute]) and so "back"
  /// returns to the sheet the user opened it from.
  void _expand(BuildContext context, QuesContentState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Quest(
          questions: [question.id],
          options: const StartTestState(
            random: false,
            randomOptionsOrder: false,
          ),
          // Whatever was already answered in the preview stays answered.
          revealAnswers: state.showCorrectAnswers,
          answers: state.selectedChoices,
        ),
      ),
    );
  }
}
