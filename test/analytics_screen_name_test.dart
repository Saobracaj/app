import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/analytics/screen_name.dart';

void main() {
  group('analyticsScreenName', () {
    test('статические пути проходят без изменений', () {
      expect(analyticsScreenName('/'), '/');
      expect(analyticsScreenName('/home'), '/home');
      expect(analyticsScreenName('/practice'), '/practice');
      expect(analyticsScreenName('/about/privacyPolicy'), '/about/privacyPolicy');
      expect(analyticsScreenName('/quest/q/zakon'), '/quest/q/zakon');
    });

    test('числовой id вопроса заменяется на плейсхолдер', () {
      expect(analyticsScreenName('/question/7923'), '/question/:id');
      expect(analyticsScreenName('/question/7923/zakon'), '/question/:id/zakon');
      expect(
        analyticsScreenName('/konspekt/question/7921'),
        '/konspekt/question/:id',
      );
    });

    test('нечисловые параметры списков, групп и инвайтов схлопываются', () {
      expect(analyticsScreenName('/lists/3f2a-uuid/q'), '/lists/:id/q');
      expect(analyticsScreenName('/groups/abc123/feed'), '/groups/:id/feed');
      expect(
        analyticsScreenName('/groups/abc123/feed/invite'),
        '/groups/:id/feed/invite',
      );
      expect(analyticsScreenName('/invite/ABC-DEF-GHI'), '/invite/:token');
      expect(
        analyticsScreenName('/support/threads/42'),
        '/support/threads/:id',
      );
    });

    test('query-параметры отбрасываются', () {
      expect(analyticsScreenName('/quest?q=1,2,3&random=true'), '/quest');
      expect(
        analyticsScreenName('/konspekt?category=25&section=manevri'),
        '/konspekt',
      );
      expect(
        analyticsScreenName('/question/7923?comments=1&thread=t1'),
        '/question/:id',
      );
    });
  });

  group('AnalyticsService', () {
    test('без инициализированного Firebase вызовы не бросают исключений', () {
      final service = AnalyticsService();
      expect(() {
        service.logScreenView('/home');
        service.logTestStarted(questionCount: 41, subcategory: '1.1');
        service.logTestFinished(
          questionCount: 41,
          rightAnswers: 39,
          score: 96,
          possibleScore: 100,
        );
        service.logLogin('password');
        service.logSignUp('password');
      }, returnsNormally);
    });
  });
}
