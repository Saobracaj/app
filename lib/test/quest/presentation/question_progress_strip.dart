import 'package:flutter/material.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

import 'question_navigator_sheet.dart';

/// The segmented progress strip under the app bar: one segment per question,
/// colored by answer status, the current one accented. Read-only — jumping to
/// a question goes through the navigator sheet.
class QuestionProgressStrip extends StatelessWidget {
  const QuestionProgressStrip({
    super.key,
    required this.entries,
    required this.currentQuestionId,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;

  @override
  Widget build(BuildContext context) {
    final quiz = Theme.of(context).quiz;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          for (final entry in entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: entry.questionId == currentQuestionId
                        ? primary
                        : switch (entry.status) {
                            QuestionStatus.unanswered => quiz.unanswered,
                            QuestionStatus.correct => quiz.correct,
                            QuestionStatus.wrong => quiz.wrong,
                          },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
