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
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/presentation/chat_page.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/chat_events.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Треды в чате с разработчиком (правки по задаче 1217567372723190):
/// шапка треда — настоящее родительское сообщение, число ответов под
/// сообщением обновляется само, а пузырь с тредом не растягивается на всю
/// ширину ленты — ссылка на тред стоит в нижней строке, справа от времени.

/// Сервер: одна переписка, один тред на сообщение `m1`.
class _FakeApi implements HttpClientAdapter {
  _FakeApi({required this.chatMessages, this.threadMessages = const []});

  /// Сообщения родительского чата (по ним же отвечает запрос «одно сообщение»).
  List<Map<String, dynamic>> chatMessages;

  /// Сообщения треда.
  List<Map<String, dynamic>> threadMessages;

  final List<String> operations = [];

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
    final variables =
        (body['variables'] as Map?)?.cast<String, dynamic>() ?? {};
    final operation = RegExp(
      r'(?:query|mutation)\s+(\w+)',
    ).firstMatch(query)!.group(1)!;
    operations.add(operation);

    final Map<String, dynamic> data;
    switch (operation) {
      case 'MySupportChat':
        data = {'mySupportChat': _chat()};
      case 'Chat':
        data = {
          'chat': variables['chatId'] == 'thread-1' ? _thread() : _chat(),
        };
      case 'OpenMessageThread':
        data = {'openMessageThread': _thread()};
      case 'Me':
        data = {
          'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
        };
      case 'ChatMessages':
        final nodes = variables['chatId'] == 'thread-1'
            ? threadMessages
            : chatMessages;
        data = {
          'chatMessages': {
            'totalCount': nodes.length,
            'hasNextPage': false,
            'nodes': nodes,
          },
        };
      case 'ChatMessage':
        data = {
          'chatMessage': [
            ...chatMessages,
            ...threadMessages,
          ].firstWhere((m) => m['id'] == variables['messageId']),
        };
      case 'MarkChatRead':
        data = {'markChatRead': 0};
      default:
        data = {};
    }
    return ResponseBody.fromString(
      json.encode({'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _chat() => {
    'id': 't1',
    'entityType': 'SUPPORT',
    'userId': 'u1',
    'userDisplayName': 'Ана',
    'createdAt': '2026-08-07T09:00:00Z',
    'unreadCount': 0,
    'messagesCount': chatMessages.length,
  };

  Map<String, dynamic> _thread() => {
    'id': 'thread-1',
    'entityType': 'MESSAGE_THREAD',
    'entityId': 'm1',
    'parentMessageId': 'm1',
    'createdAt': '2026-08-07T09:30:00Z',
    'unreadCount': 0,
    'messagesCount': threadMessages.length,
  };

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _message(
  String id, {
  String body = 'привет',
  String chatId = 't1',
  int replyCount = 0,
  String? threadChatId,
  int minute = 0,
}) => {
  'id': id,
  'threadId': chatId,
  'authorId': 'u1',
  'authorDisplayName': 'Ана',
  'fromStaff': false,
  'body': body,
  'createdAt': DateTime.utc(2026, 8, 7, 10, minute).toIso8601String(),
  'readAt': null,
  'threadChatId': threadChatId,
  'replyCount': replyCount,
  'attachments': const [],
};

ChatBloc _bloc(_FakeApi api, {ChatTarget? target}) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  final repository = ChatRepository(
    client,
    // Сокет в этих тестах не поднимается: подписка не открывается, пока по
    // адресу никто не отвечает, а проверяем мы чтение и раскладку.
    GraphqlSubscriptionClient(
      client,
      storage,
      endpoint: Uri.parse('ws://localhost:1/ws'),
      retryDelay: (_) => const Duration(days: 1),
    ),
  );
  return ChatBloc(
    repository,
    const NotificationPermissions(),
    AuthRepository(client, storage, AnalyticsService()),
    SharedListsRepository(client),
    target,
  );
}

/// Крутить цикл событий, пока условие не станет истинным (или не выйдет срок).
///
/// Фиксированная пауза здесь врёт: на загруженной машине несколько запросов
/// подряд в неё не укладываются, и тест падает не по делу.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Дать чату дочитаться: запросы уходят настоящим асинхронным кодом, который в
/// виджет-тесте крутится только внутри [WidgetTester.runAsync], а таймеры
/// самого приложения — только на игрушечных часах `pump`. Нужны оба.
Future<void> _load(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 60; i++) {
    if (until != null && until()) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// AuthBloc, всегда авторизованный: композеру важно только одно — не принять
/// участника переписки за гостя и не спрятать от него строку ввода.
class _AuthedBloc extends AuthBloc {
  _AuthedBloc()
    : super(
        AuthRepository(
          GraphqlClient(TokenStorage()),
          TokenStorage(),
          AnalyticsService(),
        ),
        GraphqlSubscriptionClient(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

/// Экран чата с настоящими переводами — и под настоящим роутером: тред
/// открывается через `pushScreen`, которому нужен Routemaster в дереве.
Widget _app() => EasyLocalization(
  useOnlyLangCode: true,
  supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
  fallbackLocale: const Locale('ru'),
  startLocale: const Locale('ru'),
  path: 'assets/translations',
  assetLoader: const CodegenLoader(),
  child: Builder(
    builder: (context) => BlocProvider<AuthBloc>(
      create: (_) => _AuthedBloc(),
      child: MaterialApp.router(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        routerDelegate: RoutemasterDelegate(
          routesBuilder: (_) => RouteMap(
            routes: {
              '/': (_) => const Redirect('/support'),
              '/support': (_) => const MaterialPage(child: ChatPage()),
            },
          ),
        ),
        routeInformationParser: const RoutemasterParser(),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'support_chat_notifications_asked': true,
    });
  });

  tearDown(() => getIt.reset());

  group('шапка треда', () {
    test('это настоящее родительское сообщение, прочитанное по id', () async {
      final api = _FakeApi(
        chatMessages: [
          _message(
            'm1',
            body: 'родительское',
            replyCount: 1,
            threadChatId: 'thread-1',
          ),
        ],
        threadMessages: [
          _message('r1', body: 'ответ', chatId: 'thread-1', minute: 5),
        ],
      );
      final bloc = _bloc(api, target: const MessageThreadTarget('m1'));
      bloc.add(ChatOpened());
      await _until(() => bloc.state.parentMessage != null);

      // Родителя нет в ленте треда — он живёт в родительском чате, поэтому
      // читается отдельным запросом. Раньше вместо него рисовалась заглушка
      // «Без имени / только что».
      expect(api.operations, contains('ChatMessage'));
      final parent = bloc.state.parentMessage;
      expect(parent, isNotNull);
      expect(parent!.body, 'родительское');
      expect(parent.authorDisplayName, 'Ана');
      expect(bloc.state.messages.map((m) => m.id), ['r1']);
      await bloc.close();
    });

    test('без родителя шапки нет — выдуманного пузыря не рисуем', () async {
      final api = _FakeApi(chatMessages: [], threadMessages: []);
      final bloc = _bloc(api, target: const MessageThreadTarget('m1'));
      bloc.add(ChatOpened());
      await _until(() => bloc.state.loaded);

      expect(bloc.state.parentMessage, isNull);
      await bloc.close();
    });
  });

  group('ссылка на тред под сообщением', () {
    testWidgets('перечитывается при возврате из треда', (tester) async {
      final api = _FakeApi(
        chatMessages: [_message('m1', body: 'вопрос')],
        threadMessages: [],
      );
      getIt.registerFactoryParam<ChatBloc, ChatTarget?, void>(
        (target, _) => _bloc(api, target: target),
      );
      await tester.pumpWidget(_app());
      await _load(
        tester,
        until: () => find.text('вопрос').evaluate().isNotEmpty,
      );
      expect(find.textContaining('ответ'), findsNothing);

      // Пока читатель был в треде, у сообщения появился ответ.
      api.chatMessages = [
        _message('m1', body: 'вопрос', replyCount: 1, threadChatId: 'thread-1'),
      ];
      api.threadMessages = [
        _message('r1', body: 'ответ', chatId: 'thread-1', minute: 5),
      ];
      await tester.longPress(find.text('вопрос'));
      await _load(
        tester,
        until: () => find.text('Ответить').evaluate().isNotEmpty,
      );
      // Меню должно доехать до места: по едущему листу палец попадает мимо
      // пункта, и лист просто закрывается.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await _load(tester, until: () => find.text('Тред').evaluate().isNotEmpty);
      expect(find.text('Тред'), findsOneWidget);
      // «Назад» из треда — и переписка перечитывается сама.
      await tester.tap(find.byType(BackButton).last);
      await _load(
        tester,
        until: () => find.text('1 ответ').evaluate().isNotEmpty,
      );

      expect(find.text('1 ответ'), findsOneWidget);
    });

    testWidgets('стоит в нижней строке справа и не растягивает пузырь', (
      tester,
    ) async {
      final api = _FakeApi(
        chatMessages: [
          _message(
            'm1',
            body: 'вопрос',
            replyCount: 1,
            threadChatId: 'thread-1',
          ),
        ],
      );
      getIt.registerFactoryParam<ChatBloc, ChatTarget?, void>(
        (target, _) => _bloc(api, target: target),
      );
      await tester.pumpWidget(_app());
      await _load(
        tester,
        until: () => find.text('1 ответ').evaluate().isNotEmpty,
      );

      final link = find.text('1 ответ');
      expect(link, findsOneWidget);
      final bubble = tester.getRect(
        find.ancestor(of: link, matching: find.byType(Card)).first,
      );
      final list = tester.getRect(find.byType(ListView));
      // Короткое сообщение с тредом остаётся узким: раньше Align внутри пузыря
      // растягивал его на всю доступную ширину.
      expect(bubble.width, lessThan(list.width * 0.6));

      // Ссылка — на одном уровне со временем и правее его.
      final time = tester.getRect(find.textContaining('назад').first);
      final linkRect = tester.getRect(link);
      expect((linkRect.center.dy - time.center.dy).abs(), lessThan(12));
      expect(linkRect.left, greaterThan(time.right));
    });
  });
}
