import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/test/quest/presentation/tabs_seen_reporter.dart';

/// Записывает вызовы вместо отправки: «имя:параметры».
class _RecordingAnalytics extends AnalyticsService {
  final events = <String>[];

  @override
  void logQuestionTabsViewed({int? questionId}) =>
      events.add('question_tabs_viewed:$questionId');

  @override
  void logQuestionTabShown({required String tab, required int questionId}) =>
      events.add('question_tab_shown:$tab:$questionId');
}

void main() {
  late _RecordingAnalytics recorded;

  setUp(() {
    recorded = _RecordingAnalytics();
    getIt.registerSingleton<AnalyticsService>(recorded);
  });

  tearDown(() => getIt.reset());

  /// The panel at [offset] from the top of a scrollable page — far enough down
  /// and it is off screen until the user scrolls.
  Widget page({
    required AppFeature tab,
    bool underQuestion = true,
    double offset = 0,
    ScrollController? controller,
  }) => MaterialApp(
    home: Scaffold(
      body: ListView(
        controller: controller,
        children: [
          SizedBox(height: offset),
          TabsSeenReporter(
            questionId: 7001,
            tab: tab,
            underQuestion: underQuestion,
            child: const SizedBox(height: 200, child: Text('tabs')),
          ),
        ],
      ),
    ),
  );

  testWidgets('панель на экране сразу — «домотал» и вкладка отмечаются по разу', (
    tester,
  ) async {
    await tester.pumpWidget(page(tab: AppFeature.questionComments));
    await tester.pump();
    // Лишние кадры и перестроения ничего не добавляют.
    await tester.pumpWidget(page(tab: AppFeature.questionComments));
    await tester.pump();

    expect(recorded.events, [
      'question_tabs_viewed:7001',
      'question_tab_shown:question_comments:7001',
    ]);
  });

  testWidgets('панель ниже экрана — события только после прокрутки к ней', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      page(
        tab: AppFeature.questionComments,
        offset: 2000,
        controller: controller,
      ),
    );
    await tester.pump();
    expect(recorded.events, isEmpty);

    controller.jumpTo(1900);
    await tester.pump();

    expect(recorded.events, [
      'question_tabs_viewed:7001',
      'question_tab_shown:question_comments:7001',
    ]);
  });

  testWidgets('смена вкладки на видимой панели отмечает новую вкладку, '
      'возврат к уже показанной — нет', (tester) async {
    await tester.pumpWidget(page(tab: AppFeature.questionComments));
    await tester.pump();
    await tester.pumpWidget(page(tab: AppFeature.categorySummaries));
    await tester.pump();
    await tester.pumpWidget(page(tab: AppFeature.questionComments));
    await tester.pump();

    expect(
      recorded.events.where((e) => e.startsWith('question_tab_shown')),
      [
        'question_tab_shown:question_comments:7001',
        'question_tab_shown:category_summaries:7001',
      ],
    );
    expect(
      recorded.events.where((e) => e.startsWith('question_tabs_viewed')),
      hasLength(1),
    );
  });

  testWidgets('боковая панель широкого экрана: вкладка отмечается, «домотал» — нет', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(tab: AppFeature.categorySummaries, underQuestion: false),
    );
    await tester.pump();

    expect(recorded.events, ['question_tab_shown:category_summaries:7001']);
  });
}
