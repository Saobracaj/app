import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/groups/data/groups_repository.dart';
import 'package:saobracaj/groups/state_management/group_feed_bloc.dart';
import 'package:saobracaj/groups/state_management/groups_bloc.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/profile/data/profile_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран группы: лента событий и разговор — две вкладки одного экрана
/// (задача 1217568064138007), а не экран и кнопка в его шапке.
///
/// Проверяется то, что в этой перестановке легко сломать: что чат не
/// открывается вместе с группой (открытие помечает сообщения прочитанными,
/// значок непрочитанного обнулился бы сам собой), что вкладка — настоящий
/// адрес, и что переключение туда-обратно не перечитывает ленту заново.

/// Сервер одной группы с одним событием и одним сообщением в чате.
class _FakeApi implements HttpClientAdapter {
  final List<String> operations = [];

  int get feedRequests => operations.where((o) => o == 'GroupFeed').length;

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
    final operation = RegExp(
      r'(?:query|mutation)\s+(\w+)',
    ).firstMatch(query)!.group(1)!;
    operations.add(operation);

    final Map<String, dynamic> data;
    switch (operation) {
      case 'GroupFeed':
        data = {
          'groupFeed': {
            'groupName': 'Ауто-школа',
            'hasMore': false,
            'events': [
              {
                'id': 'e1',
                'kind': 'MEMBER_JOINED',
                'occurredAt': '2026-08-18T09:00:00Z',
                'actor': {'id': 'u2', 'displayName': 'Мила'},
              },
            ],
          },
        };
      case 'GroupChat':
        data = {
          'chatFor': {
            'id': 'c1',
            'entityType': 'GROUP',
            'entityId': 'g1',
            'entityName': 'Ауто-школа',
            'isGroup': true,
            'createdAt': '2026-08-18T09:00:00Z',
            'unreadCount': 0,
            'messagesCount': 1,
          },
        };
      case 'ChatMessages':
        data = {
          'chatMessages': {
            'totalCount': 1,
            'hasNextPage': false,
            'nodes': [
              {
                'id': 'm1',
                'threadId': 'c1',
                'authorId': 'u2',
                'authorDisplayName': 'Мила',
                'fromStaff': false,
                'body': 'привет группе',
                'createdAt': '2026-08-18T10:00:00Z',
                'readAt': null,
                'replyCount': 0,
                'attachments': <dynamic>[],
              },
            ],
          },
        };
      case 'Me':
        data = {
          'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
        };
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

  @override
  void close({bool force = false}) {}
}

/// Приложение из одних только маршрутов группы — и это настоящие маршруты
/// приложения, а не их копия: вкладки задаются в `routes.dart`, проверять надо
/// именно их.
({Widget app, RoutemasterDelegate router}) _app(_FakeApi api) {
  final storage = TokenStorage();
  // Запросы не склеиваются в один документ: фейковый сервер отвечает по имени
  // операции, а `_Batch` ему не по зубам.
  final client = GraphqlClient(
    storage,
    dio: Dio()..httpClientAdapter = api,
    batchQueries: false,
  );
  final subscriptions = GraphqlSubscriptionClient(
    client,
    storage,
    // Сокет в этом тесте не поднимается: подписка молчит, проверяется
    // раскладка и порядок запросов.
    endpoint: Uri.parse('ws://localhost:1/ws'),
    retryDelay: (_) => const Duration(days: 1),
  );
  final groups = GroupsRepository(client, subscriptions);
  final chats = ChatRepository(client, subscriptions);
  final auth = AuthRepository(client, storage, AnalyticsService());
  final network = NetworkStatus();

  getIt.registerFactoryParam<GroupFeedBloc, String, void>(
    (groupId, _) => GroupFeedBloc(groups, network, groupId),
  );
  getIt.registerFactoryParam<ChatBloc, ChatTarget?, void>(
    (target, _) => ChatBloc(
      chats,
      const NotificationPermissions(),
      auth,
      SharedListsRepository(client),
      target,
    ),
  );

  final router = RoutemasterDelegate(
    routesBuilder: (_) => RouteMap(
      routes: {
        '/': (_) => const Redirect('/groups/g1/feed'),
        for (final path in const [
          '/groups/:id/feed',
          '/groups/:id/feed/events',
          '/groups/:id/feed/chat',
        ])
          path: routes.get(path.replaceFirst(':id', 'g1'))!.builder,
      },
    ),
  );

  final app = EasyLocalization(
    useOnlyLangCode: true,
    supportedLocales: const [Locale('ru')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => BlocProvider(
        create: (_) => GroupsBloc(
          groups,
          ProfileRepository(client),
          AuthBloc(auth, subscriptions),
          FeatureFlagsRepository(client, storage),
          network,
        ),
        child: MaterialApp.router(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          routerDelegate: router,
          routeInformationParser: const RoutemasterParser(),
        ),
      ),
    ),
  );
  return (app: app, router: router);
}

/// Дать запросам дойти: настоящий асинхронный код крутится только внутри
/// [WidgetTester.runAsync], а таймеры приложения — на игрушечных часах `pump`.
Future<void> _load(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 60; i++) {
    if (until != null && until()) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'support_chat_notifications_asked': true,
    });
    await EasyLocalization.ensureInitialized();
  });

  tearDown(() => getIt.reset());

  testWidgets('у группы две вкладки, и чат открывается только своей', (
    tester,
  ) async {
    final api = _FakeApi();
    final (:app, :router) = _app(api);
    await tester.pumpWidget(app);
    await _load(
      tester,
      until: () => find.textContaining('Мила').evaluate().isNotEmpty,
    );

    // Обе вкладки на месте, открыта лента.
    expect(find.text('События'), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.textContaining('Мила'), findsWidgets);
    // Главное: разговор не открыт. Открытие помечает сообщения прочитанными,
    // так что чат группы не должен трогаться, пока его вкладку не выбрали.
    expect(api.operations, isNot(contains('GroupChat')));

    await tester.tap(find.text('Чат'));
    await _load(
      tester,
      until: () => find.text('привет группе').evaluate().isNotEmpty,
    );

    expect(find.text('привет группе'), findsOneWidget);
    expect(api.operations, contains('GroupChat'));
    // Вкладка — настоящий адрес: ссылка из пуша ведёт прямо сюда.
    expect(router.currentConfiguration?.path, '/groups/g1/feed/chat');

    // Возврат к событиям ленту заново не читает: её Bloc живёт над вкладками.
    final feedRequests = api.feedRequests;
    await tester.tap(find.text('События'));
    await _load(tester);
    expect(find.textContaining('Мила'), findsWidgets);
    expect(api.feedRequests, feedRequests);
    expect(router.currentConfiguration?.path, '/groups/g1/feed/events');
  });
}
