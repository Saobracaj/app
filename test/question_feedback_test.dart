import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_source.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_target.dart';
import 'package:saobracaj/question_feedback/state_management/question_feedback_bloc.dart';
import 'package:saobracaj/question_feedback/state_management/question_feedback_events.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ключ общей настройки push — тот же, что у экрана уведомлений и чата.
const _pushNotifKey = 'notif_push_enabled';

/// Клиент-заглушка: сеть в этих тестах не используется.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Заглушка чата: запоминает отправленные сообщения (или падает, если задана
/// [failure]).
class _FakeSupportChat extends ChatRepository {
  _FakeSupportChat(super.client, super.subscriptions);

  final List<({String body, List<int> questionIds})> sent = [];
  Object? failure;

  /// Свой чат с разработчиком: жалоба сначала спрашивает его идентификатор.
  @override
  Future<Chat> supportChat() async =>
      Chat(id: 'c1', createdAt: DateTime(2026, 8, 7));

  @override
  Future<ChatMessage> send({
    required String chatId,
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    if (failure != null) throw failure!;
    sent.add((body: body, questionIds: questionIds));
    return ChatMessage(id: 'm1', body: body, createdAt: DateTime(2026, 8, 7));
  }
}

/// Управляемое системное разрешение на уведомления.
class _FakePermissions extends NotificationPermissions {
  _FakePermissions({
    this.granted = true,
    this.permanentlyDenied = false,
    NotificationPermissionState? afterRequest,
  }) : _afterRequest = afterRequest;

  bool granted;
  bool permanentlyDenied;
  final NotificationPermissionState? _afterRequest;
  bool openedSettings = false;
  int requests = 0;

  @override
  Future<NotificationPermissionState> status() async =>
      NotificationPermissionState(
        granted: granted,
        permanentlyDenied: permanentlyDenied,
      );

  @override
  Future<NotificationPermissionState> request() async {
    requests++;
    final result =
        _afterRequest ??
        NotificationPermissionState(
          granted: granted,
          permanentlyDenied: permanentlyDenied,
        );
    granted = result.granted;
    permanentlyDenied = result.permanentlyDenied;
    return result;
  }

  @override
  Future<void> openSettings() async {
    openedSettings = true;
  }
}

/// Сессия задаётся напрямую: настоящий переход в `authenticated` тянет за собой
/// синхронизацию статистики и фича-флаги через getIt, которых в тесте нет.
class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(super.repository, super.subscriptions, {required this.signedIn});

  final bool signedIn;

  @override
  AuthState get state => AuthState(
    status: signedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
  );
}

({
  QuestionFeedbackBloc bloc,
  _FakeSupportChat chat,
  _FakePermissions permissions,
})
_build({
  QuestionFeedbackTarget target = const QuestionFeedbackTarget.question(1234),
  QuestionFeedbackSource source = QuestionFeedbackSource.explanation,
  bool signedIn = true,
  _FakePermissions? permissions,
}) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  final subscriptions = GraphqlSubscriptionClient(client, storage);
  final chat = _FakeSupportChat(client, subscriptions);
  final perms = permissions ?? _FakePermissions();
  return (
    bloc: QuestionFeedbackBloc(
      chat,
      perms,
      AuthRepository(client, storage, AnalyticsService()),
      _FakeAuthBloc(
        AuthRepository(client, storage, AnalyticsService()),
        subscriptions,
        signedIn: signedIn,
      ),
      target,
      source,
    ),
    chat: chat,
    permissions: perms,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Отправка жалобы', () {
    test('в чат уходит шапка Report, вкладка, ссылка на вопрос и текст', () async {
      final built = _build();
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('  картинка не та  '));
      await pumpEventQueue();
      built.bloc.add(QuestionFeedbackSubmitted());
      await built.bloc.stream.firstWhere((s) => s.sent);

      final sent = built.chat.sent.single;
      expect(sent.body, '''
Report · explanation
https://saobracaj.gleb.at/question/1234

картинка не та''');
      // Вопрос уходит и явным вложением, не только ссылкой в тексте.
      expect(sent.questionIds, [1234]);
    });

    test('жалоба на конспект категории несёт ссылку на конспект и без вопросов', () async {
      final built = _build(
        target: const QuestionFeedbackTarget.konspekt('25'),
        source: QuestionFeedbackSource.konspekt,
      );
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('раздел устарел'));
      await pumpEventQueue();
      built.bloc.add(QuestionFeedbackSubmitted());
      await built.bloc.stream.firstWhere((s) => s.sent);

      final sent = built.chat.sent.single;
      expect(sent.body, '''
Report · konspekt
https://saobracaj.gleb.at/konspekt?category=25

раздел устарел''');
      // У конспекта нет вопроса — явных вложений не прикладывается.
      expect(sent.questionIds, isEmpty);
    });

    test('со вкладки конспекта источник — summary', () async {
      final built = _build(source: QuestionFeedbackSource.summary);
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('опечатка'));
      await pumpEventQueue();
      built.bloc.add(QuestionFeedbackSubmitted());
      await built.bloc.stream.firstWhere((s) => s.sent);

      expect(built.chat.sent.single.body, startsWith('Report · summary'));
    });

    test('со вкладки объяснения источник — explanation', () async {
      final built = _build(source: QuestionFeedbackSource.explanation);
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('объяснение противоречит закону'));
      await pumpEventQueue();
      built.bloc.add(QuestionFeedbackSubmitted());
      await built.bloc.stream.firstWhere((s) => s.sent);

      expect(built.chat.sent.single.body, startsWith('Report · explanation'));
    });

    test('пустой текст отправить нельзя', () async {
      final built = _build();
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('   '));
      built.bloc.add(QuestionFeedbackSubmitted());
      await pumpEventQueue();

      expect(built.bloc.state.canSend, isFalse);
      expect(built.chat.sent, isEmpty);
      expect(built.bloc.state.sent, isFalse);
    });

    test('без входа в аккаунт отправка недоступна', () async {
      final built = _build(signedIn: false);
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('текст'));
      built.bloc.add(QuestionFeedbackSubmitted());
      await pumpEventQueue();

      expect(built.bloc.state.signedIn, isFalse);
      expect(built.bloc.state.canSend, isFalse);
      expect(built.chat.sent, isEmpty);
    });

    test('ошибка отправки показывается, а текст остаётся', () async {
      final built = _build();
      built.chat.failure = Exception('сеть');
      built.bloc.add(QuestionFeedbackOpened());
      built.bloc.add(QuestionFeedbackTextChanged('текст'));
      await pumpEventQueue();
      built.bloc.add(QuestionFeedbackSubmitted());
      final state = await built.bloc.stream.firstWhere(
        (s) => s.errorMessage != null,
      );

      expect(state.sent, isFalse);
      expect(state.text, 'текст');
    });
  });

  group('Оповещения об ответе', () {
    test('переключатель выключен, если система не даёт разрешение', () async {
      final built = _build(permissions: _FakePermissions(granted: false));
      built.bloc.add(QuestionFeedbackOpened());
      await pumpEventQueue();

      expect(built.bloc.state.notify, isFalse);
      expect(built.bloc.state.signedIn, isTrue);
    });

    test('включение запрашивает разрешение и сохраняет настройку', () async {
      final built = _build(
        permissions: _FakePermissions(
          granted: false,
          afterRequest: const NotificationPermissionState(
            granted: true,
            permanentlyDenied: false,
          ),
        ),
      );
      built.bloc.add(QuestionFeedbackOpened());
      await pumpEventQueue();

      built.bloc.add(QuestionFeedbackNotifyToggled(true));
      await pumpEventQueue();

      expect(built.bloc.state.notify, isTrue);
      expect(built.permissions.requests, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_pushNotifKey), isTrue);
      // Чат с разработчиком не станет спрашивать про уведомления второй раз.
      expect(prefs.getBool('support_chat_notifications_asked'), isTrue);
    });

    test('отказ системы оставляет переключатель выключенным', () async {
      final built = _build(
        permissions: _FakePermissions(
          granted: false,
          afterRequest: const NotificationPermissionState(
            granted: false,
            permanentlyDenied: true,
          ),
        ),
      );
      built.bloc.add(QuestionFeedbackOpened());
      await pumpEventQueue();

      built.bloc.add(QuestionFeedbackNotifyToggled(true));
      await pumpEventQueue();

      expect(built.bloc.state.notify, isFalse);
      expect(built.bloc.state.notificationsBlocked, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_pushNotifKey), isNull);
    });

    test(
      'запрещённые «навсегда» уведомления отправляют в настройки системы',
      () async {
        final built = _build(
          permissions: _FakePermissions(
            granted: false,
            permanentlyDenied: true,
          ),
        );
        built.bloc.add(QuestionFeedbackOpened());
        await pumpEventQueue();

        built.bloc.add(QuestionFeedbackNotifyToggled(true));
        await pumpEventQueue();

        expect(built.bloc.state.notify, isFalse);
        expect(built.permissions.openedSettings, isTrue);
        // Системный диалог больше не показывают — запрашивать бесполезно.
        expect(built.permissions.requests, 0);
      },
    );

    test('выключение переключателя гасит общую настройку push', () async {
      SharedPreferences.setMockInitialValues({_pushNotifKey: true});
      final built = _build();
      built.bloc.add(QuestionFeedbackOpened());
      await pumpEventQueue();
      expect(built.bloc.state.notify, isTrue);

      built.bloc.add(QuestionFeedbackNotifyToggled(false));
      await pumpEventQueue();
      expect(built.bloc.state.notify, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_pushNotifKey), isFalse);
    });
  });
}
