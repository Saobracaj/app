import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_source.dart';
import 'package:saobracaj/question_feedback/domain/question_feedback_target.dart';
import 'package:saobracaj/question_feedback/state_management/question_feedback_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Полный конспект — тоже редакторский контент: жалоба должна отправляться
/// прямо с его экрана, из кнопки в шапке.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository(super.client);

  @override
  Future<Konspekt?> load(String categoryId) async => Konspekt(
    categoryId: categoryId,
    categoryName: const KonspektText(sr: 'Знаци', ru: 'Знаки'),
    sections: const [
      KonspektSection(
        id: 'osnove',
        title: KonspektText(sr: 'Основе', ru: 'Основы'),
        content: KonspektText(sr: 'Текст.', ru: 'Текст.'),
      ),
    ],
  );
}

class _FakeSupportChat extends ChatRepository {
  _FakeSupportChat(super.client, super.subscriptions);

  final List<({String body, List<int> questionIds})> sent = [];

  @override
  Future<Chat> supportChat() async =>
      Chat(id: 'c1', createdAt: DateTime(2026, 8, 26));

  @override
  Future<ChatMessage> send({
    required String chatId,
    required String body,
    List<String> attachmentIds = const [],
    List<int> questionIds = const [],
    List<String> questionListIds = const [],
  }) async {
    sent.add((body: body, questionIds: questionIds));
    return ChatMessage(id: 'm1', body: body, createdAt: DateTime(2026, 8, 26));
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
  _FakeAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

/// Включает конспекты (премиальный грант) и саму обратную связь.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(super.client, super.storage);

  static const _enabled = {
    AppFeature.categorySummaries,
    AppFeature.questionFeedback,
  };

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (!_enabled.contains(f)) f.key: false,
    },
    grants: const {'category_summaries'},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late _FakeClient client;
  late _FakeSupportChat chat;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
    client = _FakeClient(storage);
    final subscriptions = GraphqlSubscriptionClient(client, storage);
    chat = _FakeSupportChat(client, subscriptions);
    getIt.registerFactoryParam<KonspektBloc, String, String?>(
      (categoryId, section) => KonspektBloc(
        _StubKonspektRepository(client),
        NetworkStatus(),
        categoryId,
        section,
      ),
    );
    getIt.registerFactoryParam<
      QuestionFeedbackBloc,
      QuestionFeedbackTarget,
      QuestionFeedbackSource
    >(
      (target, source) => QuestionFeedbackBloc(
        chat,
        _FakePermissions(),
        AuthRepository(client, storage, AnalyticsService()),
        _FakeAuthBloc(
          AuthRepository(client, storage, AnalyticsService()),
          subscriptions,
        ),
        target,
        source,
      ),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap() => MaterialApp(
    home: BlocProvider(
      create: (_) =>
          FeatureFlagsBloc(_StubFeatureFlagsRepository(client, storage)),
      child: const KonspektPage(categoryId: '25'),
    ),
  );

  testWidgets('в шапке конспекта есть кнопка «Сообщить об ошибке»', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
  });

  testWidgets('жалоба с конспекта уходит с источником konspekt и ссылкой', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    // Без EasyLocalization в дереве tr() отдаёт сам ключ.
    expect(find.text('questionFeedback.title'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'раздел устарел');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'questionFeedback.send'),
    );
    await tester.pumpAndSettle();

    final sent = chat.sent.single;
    expect(sent.body, startsWith('Report · konspekt'));
    expect(sent.body, contains('/konspekt?category=25'));
    expect(sent.questionIds, isEmpty);
    // Диалог закрылся, подтверждение показано.
    expect(find.text('questionFeedback.title'), findsNothing);
    expect(find.text('questionFeedback.sent'), findsOneWidget);
  });

  testWidgets('без фичи question_feedback кнопки в шапке нет', (tester) async {
    // Оставляем только конспекты: гейт обратной связи выключен.
    final flags = FeatureFlagsSnapshot.resolve(
      localOverrides: {
        for (final f in AppFeature.values)
          if (f != AppFeature.categorySummaries) f.key: false,
      },
      grants: const {'category_summaries'},
      authenticated: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FeatureFlagsBloc(
            _FixedFlagsRepository(client, storage, flags),
          ),
          child: const KonspektPage(categoryId: '25'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flag_outlined), findsNothing);
  });
}

/// Репозиторий с заранее решённым снапшотом флагов.
class _FixedFlagsRepository extends FeatureFlagsRepository {
  _FixedFlagsRepository(super.client, super.storage, this._snapshot);

  final FeatureFlagsSnapshot _snapshot;

  @override
  FeatureFlagsSnapshot get snapshot => _snapshot;

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(_snapshot);
}
