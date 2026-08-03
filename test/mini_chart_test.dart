import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/categories.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';

Future<void> _pumpChart(WidgetTester tester, SubStats stats) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: MiniChart(stats: stats))),
    ),
  );
}

void main() {
  group('MiniChart', () {
    testWidgets(
      'тест завершён с нулём отвеченных вопросов не роняет layout (NaN constraints)',
      (tester) async {
        // Регресс: сессия с нулём правильных ответов давала maxValue=0,
        // из-за чего value/maxValue = 0/0 = NaN -> BoxConstraints has NaN values.
        await _pumpChart(tester, const SubStats(answers: [0], allAnswers: 0));

        expect(tester.takeException(), isNull);
        expect(find.byType(MiniChart), findsOneWidget);
      },
    );

    testWidgets('обычная статистика рендерится без исключений', (tester) async {
      await _pumpChart(
        tester,
        const SubStats(answers: [3, 5, 8], allAnswers: 8),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('пустой список ответов не роняет layout', (tester) async {
      await _pumpChart(tester, const SubStats(answers: [], allAnswers: 0));

      expect(tester.takeException(), isNull);
    });
  });
}
