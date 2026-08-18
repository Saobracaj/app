import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_source.dart';
import 'package:saobracaj/question_feedback/presentation/report_problem_button.dart';
import 'package:saobracaj/question_feedback/state_management/question_feedback_bloc.dart';
import 'package:saobracaj/support_chat/data/support_chat_repository.dart';
import 'package:saobracaj/support_chat/models/support_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeSupportChat extends SupportChatRepository {
  _FakeSupportChat(super.client, super.subscriptions);

  final List<({String body, List<int> questionIds})> messages = [];

  @override
  Future<SupportMessage> send({
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    messages.add((body: body, questionIds: questionIds));
    return SupportMessage(id: 'm1', body: body, createdAt: DateTime(2026, 8, 7));
  }
}

class _FakePermissions extends NotificationPermissions {
  @override
  Future<NotificationPermissionState> status() async =>
      const NotificationPermissionState(
        granted: true,
        permanentlyDenied: false,
      );

  @override
  Future<NotificationPermissionState> request() async => status();

  @override
  Future<void> openSettings() async {}
}

class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(super.repository, super.subscriptions, {required this.signedIn});

  final bool signedIn;

  @override
  AuthState get state => AuthState(
    status: signedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated,
  );
}

/// Включает ровно фичу обратной связи — кнопка живёт под её флагом.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(super.client, super.storage);

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (f != AppFeature.questionFeedback) f.key: false,
    },
    grants: const {},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSupportChat chat;
  late TokenStorage storage;
  late _FakeClient client;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
    client = _FakeClient(storage);
    final subscriptions = GraphqlSubscriptionClient(client, storage);
    chat = _FakeSupportChat(client, subscriptions);
    getIt.registerFactoryParam<QuestionFeedbackBloc, int, QuestionFeedbackSource>(
      (questionId, source) => QuestionFeedbackBloc(
        chat,
        _FakePermissions(),
        AuthRepository(client, storage, AnalyticsService()),
        _FakeAuthBloc(
          AuthRepository(client, storage, AnalyticsService()),
          subscriptions,
          signedIn: true,
        ),
        questionId,
        source,
      ),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap() => MaterialApp(
    home: BlocProvider(
      create: (_) => FeatureFlagsBloc(_StubFeatureFlagsRepository(client, storage)),
      child: const Scaffold(
        body: ReportProblemButton(
          questionId: 7001,
          source: QuestionFeedbackSource.discussion,
        ),
      ),
    ),
  );

  testWidgets('жалоба из диалога уходит в чат с разработчиком', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Без EasyLocalization в дереве tr() отдаёт сам ключ.
    await tester.tap(find.text('questionFeedback.report'));
    await tester.pumpAndSettle();
    expect(find.text('questionFeedback.title'), findsOneWidget);

    // Пустую жалобу отправить нельзя.
    final send = find.widgetWithText(FilledButton, 'questionFeedback.send');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ответ неверный');
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(chat.messages.single.body, contains('ответ неверный'));
    expect(chat.messages.single.body, startsWith('Report · discussion'));
    expect(chat.messages.single.questionIds, [7001]);
    // Диалог закрылся, а пользователю показали подтверждение.
    expect(find.text('questionFeedback.title'), findsNothing);
    expect(find.text('questionFeedback.sent'), findsOneWidget);
  });

  testWidgets('«Отмена» закрывает диалог и ничего не отправляет', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('questionFeedback.report'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'передумал');
    await tester.pumpAndSettle();

    await tester.tap(find.text('questionFeedback.cancel'));
    await tester.pumpAndSettle();

    expect(find.text('questionFeedback.title'), findsNothing);
    expect(chat.messages, isEmpty);
  });
}
