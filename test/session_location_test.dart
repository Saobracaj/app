import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/session/session_sync_service.dart';

void main() {
  group('isResumableLocation — какие экраны переносим между устройствами', () {
    test('прохождение вопросов переносится (с query-параметрами)', () {
      expect(isResumableLocation('/quest?q=1,2,3&subcategory=B'), isTrue);
      expect(isResumableLocation('/questPractice?showRightAnswers=true'), isTrue);
      expect(isResumableLocation('/statistics/q?q=5'), isTrue);
      expect(isResumableLocation('/zakon?chapter=2'), isTrue);
    });

    test('главный экран и корень не переносим (это шум, а не продолжение)', () {
      expect(isResumableLocation('/'), isFalse);
      expect(isResumableLocation(''), isFalse);
    });

    test('экраны авторизации/профиля не переносим между устройствами', () {
      expect(isResumableLocation('/login'), isFalse);
      expect(isResumableLocation('/register'), isFalse);
      expect(isResumableLocation('/resetPassword'), isFalse);
      expect(isResumableLocation('/confirmCode?email=a@b.c'), isFalse);
      expect(isResumableLocation('/profile'), isFalse);
    });

    test('префикс похожего пути не считается исключённым', () {
      // '/logins' не должен трактоваться как '/login'.
      expect(isResumableLocation('/logins'), isTrue);
    });
  });
}
