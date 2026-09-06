import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
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
import 'package:saobracaj/chat/models/chat_target.dart';
import 'package:saobracaj/chat/presentation/question_chat_section.dart';
import 'package:saobracaj/chat/state_management/chat_bloc.dart';
import 'package:saobracaj/chat/state_management/chat_events.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/profile/data/profile_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Имя перед первым сообщением (задача 1218209972696859).
///
/// Собеседник, у которого имени нет, подписан «Без имени» — поэтому сообщение
/// не уходит, пока имя не указано: экран просит его диалогом, а отказ отменяет
/// отправку, не теряя написанного.

/// Сервер: один разговор о вопросе, профиль с именем или без и мутация,
/// которой имя ставится.
class _FakeApi implements HttpClientAdapter {
  _FakeApi({this.displayName = '', this.profileFails = false});

  /// Имя в профиле: пустое — автор ещё безымянный.
  String displayName;

  /// Профиль не читается (нет связи, сервер молчит).
  final bool profileFails;

  final List<String> operations = [];
  final List<Map<String, dynamic>> variables = [];

  Map<String, dynamic> varsOf(String operation) =>
      variables[operations.indexOf(operation)];

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

    if (operation == 'MyProfile' && profileFails) {
      return ResponseBody.fromString(
        json.encode({
          'errors': [
            {'message': 'boom'},
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final Map<String, dynamic> data = switch (operation) {
      'QuestionChat' => {'chatFor': _chat()},
      'Me' => {
        'me': const {'id': 'u1', 'email': 'u@e', 'permissions': []},
      },
      'MyProfile' => {
        'myProfile': {'displayName': displayName, 'commentBan': false},
      },
      'SetDisplayName' => {
        'setDisplayName': {
          'displayName': displayName = vars['displayName'] as String,
          'commentBan': false,
        },
      },
      'ChatMessages' => {
        'chatMessages': const {
          'totalCount': 0,
          'hasNextPage': false,
          'nodes': [],
        },
      },
      'SendChatMessage' => {
        'sendChatMessage': {
          'id': 'sent',
          'authorId': 'u1',
          'authorDisplayName': displayName,
          'fromStaff': false,
          'body': vars['body'],
          'createdAt': '2026-09-06T10:00:00Z',
        },
      },
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
    'createdAt': '2026-09-06T09:00:00Z',
    'unreadCount': 0,
    'messagesCount': 0,
  };

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

/// AuthBloc с раз и навсегда заданным статусом: композер спрашивает у него
/// только одно — вошёл ли пользователь.
class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._status)
    : super(
        AuthRepository(
          GraphqlClient(
            TokenStorage(),
            dio: Dio()..httpClientAdapter = _FakeApi(),
          ),
          TokenStorage(),
          AnalyticsService(),
        ),
        GraphqlSubscriptionClient(
          GraphqlClient(
            TokenStorage(),
            dio: Dio()..httpClientAdapter = _FakeApi(),
          ),
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

ChatBloc _bloc(_FakeApi api) {
  final storage = TokenStorage();
  final client = GraphqlClient(storage, dio: Dio()..httpClientAdapter = api);
  return ChatBloc(
    ChatRepository(
      client,
      GraphqlSubscriptionClient(
        client,
        storage,
        endpoint: Uri.parse('ws://localhost:1/ws'),
        retryDelay: (_) => const Duration(days: 1),
      ),
    ),
    const NotificationPermissions(),
    AuthRepository(client, storage, AnalyticsService()),
    SharedListsRepository(client),
    ProfileRepository(client),
    const QuestionChatTarget(7921),
  );
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Открытый разговор с набранным, но ещё не отправленным сообщением.
Future<ChatBloc> _composed(_FakeApi api, {String body = 'привет'}) async {
  final bloc = _bloc(api);
  bloc.add(ChatOpened());
  await _until(() => bloc.state.loaded);
  bloc.add(ChatBodyChanged(body));
  await _until(() => bloc.state.body == body);
  return bloc;
}

/// Вкладка обсуждения на готовом [bloc] — как на настоящей странице вопроса.
Future<void> _pumpSection(WidgetTester tester, ChatBloc bloc) async {
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
                  BlocProvider<AuthBloc>(
                    create: (_) => _FixedAuthBloc(AuthStatus.authenticated),
                  ),
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

  group('имя перед отправкой', () {
    test('безымянный автор ничего не отправляет — экран просит имя', () async {
      final api = _FakeApi();
      final bloc = await _composed(api);

      bloc.add(ChatSendPressed());
      await _until(() => bloc.state.displayNamePrompt);

      expect(bloc.state.displayNamePrompt, isTrue);
      expect(api.operations, isNot(contains('SendChatMessage')));
      // Написанное остаётся в поле ввода: разговор не начат, а не потерян.
      expect(bloc.state.body, 'привет');
      await bloc.close();
    });

    test('имя из диалога сохраняется, и сообщение уходит следом', () async {
      final api = _FakeApi();
      final bloc = await _composed(api);

      bloc.add(ChatSendPressed());
      await _until(() => bloc.state.displayNamePrompt);
      bloc.add(ChatDisplayNameSubmitted('Ана'));
      await _until(() => bloc.state.messages.isNotEmpty);

      expect(api.operations, contains('SetDisplayName'));
      expect(api.varsOf('SetDisplayName')['displayName'], 'Ана');
      expect(api.operations, contains('SendChatMessage'));
      expect(api.varsOf('SendChatMessage')['body'], 'привет');
      expect(bloc.state.displayNamePrompt, isFalse);
      expect(bloc.state.body, isEmpty);
      await bloc.close();
    });

    test('отказ отменяет отправку и не трогает написанное', () async {
      final api = _FakeApi();
      final bloc = await _composed(api);

      bloc.add(ChatSendPressed());
      await _until(() => bloc.state.displayNamePrompt);
      bloc.add(ChatDisplayNameCancelled());
      await _until(() => !bloc.state.displayNamePrompt);

      expect(api.operations, isNot(contains('SendChatMessage')));
      expect(bloc.state.body, 'привет');
      expect(bloc.state.sending, isFalse);
      await bloc.close();
    });

    test('второе сообщение имя уже не спрашивает', () async {
      final api = _FakeApi();
      final bloc = await _composed(api);

      bloc.add(ChatSendPressed());
      await _until(() => bloc.state.displayNamePrompt);
      bloc.add(ChatDisplayNameSubmitted('Ана'));
      await _until(() => bloc.state.messages.isNotEmpty);

      bloc.add(ChatBodyChanged('и ещё'));
      await _until(() => bloc.state.body == 'и ещё');
      bloc.add(ChatSendPressed());
      await _until(
        () => api.operations.where((o) => o == 'SendChatMessage').length == 2,
      );

      expect(bloc.state.displayNamePrompt, isFalse);
      // Профиль перечитывается только пока имени нет.
      expect(api.operations.where((o) => o == 'SetDisplayName'), hasLength(1));
      await bloc.close();
    });

    test('у автора с именем ничего не спрашивают', () async {
      final api = _FakeApi(displayName: 'Ана');
      final bloc = await _composed(api);

      bloc.add(ChatSendPressed());
      await _until(() => bloc.state.messages.isNotEmpty);

      expect(bloc.state.displayNamePrompt, isFalse);
      expect(api.operations, contains('SendChatMessage'));
      await bloc.close();
    });

    test('нечитаемый профиль отправку не блокирует', () async {
      // Проверка не удалась — это не повод не отправить: ещё одно «Без имени»
      // лучше, чем разговор, в который нельзя написать из-за связи.
      final api = _FakeApi(profileFails: true);
      final bloc = await _composed(api);

      bloc.add(ChatSendPressed());
      await _until(() => bloc.state.messages.isNotEmpty);

      expect(bloc.state.displayNamePrompt, isFalse);
      expect(api.operations, contains('SendChatMessage'));
      await bloc.close();
    });
  });

  group('диалог на экране обсуждения', () {
    testWidgets('кнопка отправки открывает диалог, отказ ничего не шлёт', (
      tester,
    ) async {
      final api = _FakeApi();
      late final ChatBloc bloc;
      await tester.runAsync(() async => bloc = await _composed(api));

      await _pumpSection(tester, bloc);
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.send));
        await _until(() => bloc.state.displayNamePrompt);
      });
      await tester.pump();

      expect(find.text('Отображаемое имя'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pump();
      await tester.runAsync(() async => _until(() => true));

      expect(find.text('Отображаемое имя'), findsNothing);
      expect(api.operations, isNot(contains('SendChatMessage')));
      await tester.runAsync(bloc.close);
    });

    testWidgets('введённое в диалоге имя отправляет сообщение', (tester) async {
      final api = _FakeApi();
      late final ChatBloc bloc;
      await tester.runAsync(() async => bloc = await _composed(api));

      await _pumpSection(tester, bloc);
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.send));
        await _until(() => bloc.state.displayNamePrompt);
      });
      await tester.pump();

      await tester.enterText(find.byType(TextField).last, 'Ана');
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.runAsync(
        () async => _until(() => bloc.state.messages.isNotEmpty),
      );

      expect(api.operations, contains('SetDisplayName'));
      expect(api.operations, contains('SendChatMessage'));
      await tester.runAsync(bloc.close);
    });
  });
}
