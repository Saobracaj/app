import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/groups/presentation/group_feed_page.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

/// The colour under a feed result has to read the same way as the little charts
/// under the categories on the home screen — that is the "цветовой индикатор"
/// the feed was asked for. This pins the thresholds to `MiniChart.barColors`.
void main() {
  testWidgets('a result is coloured on the same scale as the category charts', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final quiz = Theme.of(context).quiz;

    // Everything right.
    expect(scoreColors(context, 20, 20).$1, quiz.correct);
    // One short of perfect: "almost there".
    expect(scoreColors(context, 19, 20).$1, quiz.warning);
    // Comfortably in the middle.
    expect(scoreColors(context, 14, 20).$1, quiz.info);
    // Less than half.
    expect(scoreColors(context, 9, 20).$1, quiz.wrong);
    // A result with no questions in it must not divide by zero.
    expect(scoreColors(context, 0, 0).$1, quiz.info);
  });
}
