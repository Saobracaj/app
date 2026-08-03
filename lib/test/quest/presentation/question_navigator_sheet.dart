import 'package:flutter/material.dart';

import '../../../theme/quiz_colors.dart';

/// How one question of the current run has turned out so far.
enum QuestionStatus { unanswered, correct, wrong }

/// One row of the navigator — also the model the progress strip renders, so the
/// strip and the sheet can never disagree about a question's state.
class QuestionNavigatorEntry {
  const QuestionNavigatorEntry({
    required this.questionId,
    required this.number,
    required this.points,
    required this.status,
  });

  final int questionId;

  /// 1-based position within this run, which is what the user is shown.
  final int number;
  final int points;
  final QuestionStatus status;
}

/// Opens the question list for the training quiz and resolves to the id of the
/// question the user picked, or `null` if they dismissed it.
///
/// This is the trainer's counterpart to the simulation's "Извештај" table: the
/// exam replica may not reveal whether an answer was right, this one may — so
/// the two deliberately stay separate widgets.
Future<int?> showQuestionNavigator(
  BuildContext context, {
  required List<QuestionNavigatorEntry> entries,
  required int currentQuestionId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => _QuestionNavigator(
        entries: entries,
        currentQuestionId: currentQuestionId,
        controller: controller,
      ),
    ),
  );
}

class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.entries,
    required this.currentQuestionId,
    required this.controller,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isCurrent = entry.questionId == currentQuestionId;
        return ListTile(
          selected: isCurrent,
          leading: _StatusDot(status: entry.status),
          title: Text('Питање ${entry.number}'),
          subtitle: Text('Број поена: ${entry.points}'),
          trailing: isCurrent ? const Icon(Icons.arrow_right_alt) : null,
          onTap: () => Navigator.of(context).pop(entry.questionId),
        );
      },
    );
  }
}

/// The same three-state dot the progress strip uses, at a size that reads in a
/// list row.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final QuestionStatus status;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    final color = switch (status) {
      QuestionStatus.unanswered => quiz.unanswered,
      QuestionStatus.correct => quiz.correct,
      QuestionStatus.wrong => quiz.wrong,
    };
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
