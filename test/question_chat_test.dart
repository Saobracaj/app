import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/presentation/chat_page.dart';
import 'package:saobracaj/chat/presentation/question_chat_section.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/chat_events.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Обсуждение вопроса — тот же чат приложения, но открытый по номеру вопроса и
/// перевёрнутый на странице. Здесь проверяется то, что у него своего: как он
/// открывается, как подгружается история и в каком порядке идут сообщения.

/// Сервер с разговором из [total] сообщений, отдающий их страницами.
class _FakeApi implements HttpClientAdapter {
  _FakeApi({this.total = 3});

  final int total;
  final List<String> operations = [];
  final List<Map<String, dynamic>> variables = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final raw = options.data;
    final body = raw is String
        ? json.decode(raw) as Map<String, dynamic>
        : (raw as Map).cast<String, dynamic>();
    final query = body['query'].toString();
    final vars = (body['variables'] as Map?)?.cast<String, dynamic>() ?? {};
    final operation = RegExp(
      r'(?:query|mutation)\s+(\w+)',
    ).firstMatch(query)!.group(1)!;
    operations.add(operation);
    variables.add(vars);
    if (operation == 'QuestionChat') {
      expect(query, contains('entityType: QUESTION'));
    }

    final Map<String, dynamic> data = switch (operation) {
      'QuestionChat' => {'chatFor': _chat()},
      'Chat' => {'chat': _chat()},
      'Me' => {
        'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
      },
      'ChatMessages' => {'chatMessages': _page(vars)},
      'MarkChatRead' => {'markChatRead': 0},
      _ => const {},
    };
    return ResponseBody.fromString(
      json.encode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _chat() => {
    'id': 'c1',
    'entityType': 'QUESTION',
    'entityId': '7921',
    'entityName': '',
    'isGroup': true,
    'userId': '',
    'userDisplayName': '',
    'createdAt': '2026-08-18T09:00:00Z',
    'unreadCount': 0,
    'messagesCount': total,
  };

  /// Страница сообщений «от старых к новым», как её отдаёт бэкенд.
  Map<String, dynamic> _page(Map<String, dynamic> vars) {
    final offset = (vars['offset'] as num?)?.toInt() ?? 0;
    final limit = (vars['limit'] as num?)?.toInt() ?? 50;
    final nodes = [
      for (var i = offset; i < total && i < offset + limit; i++)
        {
          'id': 'm$i',
          'authorId': i.isEven ? 'u1' : 'u2',
          'authorDisplayName': i.isEven ? 'Я' : 'Другой',
          'fromStaff': false,
          'body': 'сообщение $i',
          // Время строго растёт: порядок в ленте — это порядок отправки.
          'createdAt': DateTime.utc(
            2026,
            8,
            18,
            9,
          ).add(Duration(minutes: i)).toIso8601String(),
        },
    ];
    return {
      'totalCount': total,
      'hasNextPage': offset + nodes.length < total,
      'nodes': nodes,
    };
  }

  @override
  void close({bool force = false}) {}
}

/// Сокет подписки, который никуда не соединяется.
class _DeadSocket implements GraphqlSocket {
  final _controller = StreamController<dynamic>();

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  void send(String message) {}

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// AuthBloc с раз и навсегда заданным статусом — от него в обсуждении зависит
/// только одно: показывать ли гостю приглашение войти вместо строки ввода.
class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._status)
    : super(
        AuthRepository(
          GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = _FakeApi()),
          TokenStorage(),
          AnalyticsService(),
        ),
        GraphqlSubscriptionClient(
          GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = _FakeApi()),
          TokenStorage(),
          connector: (_) async => _DeadSocket(),
          endpoint: Uri.parse('ws://localhost:8080/ws'),
          retryDelay: (_) => Duration.zero,
        ),
      );

  final AuthStatus _status;

  @override
  AuthState get state => AuthState(status: _status);
}

ChatBloc _bloc(_FakeApi api, {int questionId = 7921}) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  final repository = ChatRepository(
    client,
    GraphqlSubscriptionClient(
      client,
      storage,
      connector: (_) async => _DeadSocket(),
      endpoint: Uri.parse('ws://localhost:8080/ws'),
      retryDelay: (_) => Duration.zero,
    ),
  );
  return ChatBloc(
    repository,
    const NotificationPermissions(),
    AuthRepository(client, storage, AnalyticsService()),
    SharedListsRepository(client),
    QuestionChatTarget(questionId),
  );
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Вкладка обсуждения на готовом [bloc]: локализация, AuthBloc с заданным
/// статусом и прокрутка страницы вокруг — как на настоящем экране вопроса.
Future<void> _pumpSection(
  WidgetTester tester,
  ChatBloc bloc, {
  required AuthStatus auth,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      useOnlyLangCode: true,
      ignorePluralRules: false,
      supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
      fallbackLocale: const Locale('ru'),
      startLocale: const Locale('ru'),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const CodegenLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<AuthBloc>(create: (_) => _FixedAuthBloc(auth)),
                  BlocProvider.value(value: bloc),
                ],
                child: const QuestionChatView(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('открытие обсуждения', () {
    test('идёт через chatFor(QUESTION) с номером вопроса', () async {
      final api = _FakeApi();
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);

      expect(api.operations, contains('QuestionChat'));
      expect(
        api.variables[api.operations.indexOf('QuestionChat')]['questionId'],
        '7921',
      );
      expect(bloc.state.messages, hasLength(3));
      // Вся история уже на экране — подгружать нечего.
      expect(bloc.state.hasOlder, isFalse);
      unawaited(bloc.close());
    });

    test('не тратит единственное предложение про оповещения', () async {
      final api = _FakeApi();
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);

      expect(bloc.state.notificationsPrompt, isFalse);
      unawaited(bloc.close());
    });
  });

  group('история', () {
    test('читается хвостом, а страница назад дочитывает старое', () async {
      final api = _FakeApi(total: 120);
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);

      // Хвост: последние 50 из 120, и выше есть ещё.
      expect(bloc.state.messages, hasLength(50));
      expect(bloc.state.messages.first.id, 'm70');
      expect(bloc.state.hasOlder, isTrue);

      bloc.add(ChatOlderRequested());
      await _until(() => bloc.state.messages.length > 50);
      expect(bloc.state.messages, hasLength(100));
      expect(bloc.state.messages.first.id, 'm20');
      expect(bloc.state.hasOlder, isTrue);

      // Последний шаг упирается в начало разговора.
      bloc.add(ChatOlderRequested());
      await _until(() => !bloc.state.hasOlder);
      expect(bloc.state.messages, hasLength(120));
      expect(bloc.state.messages.first.id, 'm0');
      unawaited(bloc.close());
    });

    test('дочитанное не схлопывается при перечитывании разговора', () async {
      final api = _FakeApi(total: 120);
      final bloc = _bloc(api);
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);
      bloc.add(ChatOlderRequested());
      await _until(() => bloc.state.messages.length > 50);

      bloc.add(ChatRefreshed());
      await _until(() => !bloc.state.loading);
      expect(bloc.state.messages, hasLength(100));
      expect(bloc.state.hasOlder, isTrue);
      unawaited(bloc.close());
    });
  });

  group('перевёрнутая вкладка', () {
    testWidgets('поле ввода стоит над самым свежим сообщением', (tester) async {
      final api = _FakeApi(total: 3);
      // Bloc открывается в настоящем зоне-времени: события и запросы Dio под
      // часами теста не двигаются, а виджету нужно только готовое состояние.
      late final ChatBloc bloc;
      await tester.runAsync(() async {
        bloc = _bloc(api);
        bloc.add(ChatOpened());
        await _until(() => bloc.state.messages.isNotEmpty);
      });

      await _pumpSection(tester, bloc, auth: AuthStatus.authenticated);

      final composer = tester.getTopLeft(find.byType(ChatComposer)).dy;
      final newest = tester.getTopLeft(find.text('сообщение 2')).dy;
      final oldest = tester.getTopLeft(find.text('сообщение 0')).dy;
      expect(composer, lessThan(newest), reason: 'ввод сверху');
      expect(
        newest,
        lessThan(oldest),
        reason: 'свежее выше, дальше вниз — в прошлое',
      );
      await tester.runAsync(bloc.close);
    });

    testWidgets('гость читает ленту, но вместо поля ввода — приглашение войти', (
      tester,
    ) async {
      final api = _FakeApi(total: 3);
      late final ChatBloc bloc;
      await tester.runAsync(() async {
        bloc = _bloc(api);
        bloc.add(ChatOpened());
        await _until(() => bloc.state.messages.isNotEmpty);
      });

      await _pumpSection(tester, bloc, auth: AuthStatus.unauthenticated);

      // Сообщения видны и без входа…
      expect(find.text('сообщение 2'), findsOneWidget);
      // …а писать нечем: ни поля ввода, ни кнопки отправить — только
      // объяснение и кнопка входа.
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text('Войдите в аккаунт, чтобы писать в обсуждении и ставить реакции.'),
        findsOneWidget,
      );
      expect(find.text('Войти'), findsOneWidget);
      await tester.runAsync(bloc.close);
    });
  });

  group('ссылка на сообщение', () {
    test('открывает вкладку обсуждения и по старому имени параметров', () {
      expect(routes.get('/question/7921?chat=1&message=m7'), isNotNull);
      expect(routes.get('/question/7921?comments=1&thread=m7'), isNotNull);
    });
  });
}
