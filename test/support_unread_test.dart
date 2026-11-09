import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/models/viewer.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/chat/data/chat_repository.dart';
import 'package:saobracaj/chat/models/chat.dart';
import 'package:saobracaj/chat/presentation/support_unread_button.dart';
import 'package:saobracaj/chat/state_management/support_unread_bloc.dart';
import 'package:saobracaj/chat/state_management/support_unread_events.dart';
import 'package:saobracaj/chat/state_management/support_unread_state.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/core/presentation/app_sidebar.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/notifications/data/push_message_service.dart';
import 'package:saobracaj/theme/state_management/theme_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Непрочитанное в чате с разработчиком на главной (SAOBR-546): пока есть
/// непрочитанное, на месте аватара стоит кнопка со счётчиком, ведущая в
/// нужный разговор — свой чат, обращение или тред; прочитали — возвращается
/// аватар.

/// Сервер: отдаёт список разговоров с непрочитанным и помнит, о чём спрашивали.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  List<Map<String, dynamic>> unread = const [];
  final List<String> operations = [];

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    final operation =
        RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(query)?.group(1) ?? '';
    operations.add(operation);
    switch (operation) {
      case 'MySupportUnreadChats':
        return {'mySupportUnreadChats': unread};
      case 'MarkChatRead':
        return const {'markChatRead': 1};
      default:
        return const {};
    }
  }
}

/// AuthBloc с раз и навсегда заданным состоянием: счётчику от него нужны
/// только статус и права вошедшего.
class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._fixed, GraphqlClient client, TokenStorage storage)
    : super(
        AuthRepository(client, storage, AnalyticsService()),
        GraphqlSubscriptionClient(client, storage),
      );

  final AuthState _fixed;

  @override
  AuthState get state => _fixed;
}

AuthState _signedIn({List<String> permissions = const []}) => AuthState(
  status: AuthStatus.authenticated,
  viewer: Viewer(id: 'u1', email: 'ana@example.com', permissions: permissions),
);

Map<String, dynamic> _chatJson(
  String id, {
  String entityType = 'SUPPORT',
  int unread = 1,
}) => {
  'id': id,
  'entityType': entityType,
  'userId': 'u1',
  'createdAt': '2026-11-09T10:00:00Z',
  'unreadCount': unread,
  if (entityType == 'MESSAGE_THREAD') 'parentMessageId': 'm1',
};

Chat _chat(String id, {bool thread = false, int unread = 1}) => Chat.parse(
  _chatJson(
    id,
    entityType: thread ? 'MESSAGE_THREAD' : 'SUPPORT',
    unread: unread,
  ),
);

class _Harness {
  _Harness(AuthState auth) {
    client = _FakeClient(storage);
    authBloc = _FixedAuthBloc(auth, client, storage);
    repository = ChatRepository(
      client,
      GraphqlSubscriptionClient(client, storage),
    );
    bloc = SupportUnreadBloc(
      repository,
      authBloc,
      network,
      PushMessageService(),
    );
  }

  final storage = TokenStorage();
  final network = NetworkStatus();
  late final _FakeClient client;
  late final AuthBloc authBloc;
  late final ChatRepository repository;
  late final SupportUnreadBloc bloc;

  Future<void> close() async {
    await bloc.close();
    await authBloc.close();
  }
}

/// Дождаться состояния, удовлетворяющего [test] (оно могло наступить и до
/// подписки на поток).
Future<SupportUnreadState> _until(
  SupportUnreadBloc bloc,
  bool Function(SupportUnreadState) test,
) async {
  if (test(bloc.state)) return bloc.state;
  return bloc.stream.firstWhere(test).timeout(const Duration(seconds: 2));
}

/// Прокачать несколько кадров: `pumpAndSettle` здесь не годится — под шапкой
/// и в колонке могут жить бесконечные анимации.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _localized(Widget child) => EasyLocalization(
  useOnlyLangCode: true,
  supportedLocales: const [Locale('ru')],
  fallbackLocale: const Locale('ru'),
  startLocale: const Locale('ru'),
  path: 'assets/translations',
  assetLoader: const CodegenLoader(),
  child: Builder(
    builder: (context) => MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('куда ведёт кнопка', () {
    test('без непрочитанного — никуда', () {
      expect(const SupportUnreadState().destination, isNull);
      expect(
        SupportUnreadState(chats: [_chat('c1', unread: 0)]).destination,
        isNull,
      );
    });

    test('своё обращение — в чат с разработчиком', () {
      final state = SupportUnreadState(chats: [_chat('c1')]);
      expect(state.destination, '/support');
      expect(state.total, 1);
    });

    test('один тред — в сам тред', () {
      final state = SupportUnreadState(chats: [_chat('t9', thread: true)]);
      expect(state.destination, '/chat/t9');
    });

    test('модератору одно обращение открывается из списка обращений', () {
      final state = SupportUnreadState(chats: [_chat('c1')], moderator: true);
      expect(state.destination, '/support/threads/c1');
    });

    test('несколько разговоров — корень: свой чат или список обращений', () {
      final chats = [_chat('c1', unread: 2), _chat('t9', thread: true)];
      expect(SupportUnreadState(chats: chats).destination, '/support');
      expect(
        SupportUnreadState(chats: chats, moderator: true).destination,
        '/support/threads',
      );
      expect(SupportUnreadState(chats: chats).total, 3);
    });
  });

  group('SupportUnreadBloc', () {
    test('гость ничего не спрашивает', () async {
      final h = _Harness(const AuthState(status: AuthStatus.unauthenticated));
      h.bloc.add(const SupportUnreadStarted(watchLifecycle: false));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(h.client.operations, isEmpty);
      expect(h.bloc.state.hasUnread, isFalse);
      await h.close();
    });

    test(
      'вошедший читает список; пометка «прочитано» перечитывает его',
      () async {
        final h = _Harness(_signedIn());
        h.client.unread = [
          _chatJson('c1', unread: 2),
          _chatJson('t9', entityType: 'MESSAGE_THREAD'),
        ];
        h.bloc.add(const SupportUnreadStarted(watchLifecycle: false));
        final loaded = await _until(h.bloc, (s) => s.hasUnread);
        expect(loaded.total, 3);
        expect(loaded.moderator, isFalse);
        expect(loaded.destination, '/support');

        // Пользователь открыл чат здесь же — репозиторий пометил его прочитанным.
        h.client.unread = [_chatJson('t9', entityType: 'MESSAGE_THREAD')];
        await h.repository.markRead('c1');
        final after = await _until(h.bloc, (s) => s.total == 1);
        expect(after.destination, '/chat/t9');
        expect(
          h.client.operations.where((o) => o == 'MySupportUnreadChats').length,
          2,
        );
        await h.close();
      },
    );

    test('сторона модератора — по праву moderate_support', () async {
      final h = _Harness(
        _signedIn(permissions: const [SupportUnreadBloc.moderatorPermission]),
      );
      h.client.unread = [_chatJson('c7')];
      h.bloc.add(const SupportUnreadStarted(watchLifecycle: false));
      final loaded = await _until(h.bloc, (s) => s.hasUnread);
      expect(loaded.moderator, isTrue);
      expect(loaded.destination, '/support/threads/c7');
      await h.close();
    });

    test('возврат сети перечитывает список', () async {
      final h = _Harness(_signedIn());
      h.bloc.add(const SupportUnreadStarted(watchLifecycle: false));
      await _until(h.bloc, (s) => !s.hasUnread);
      await Future<void>.delayed(Duration.zero);
      final before = h.client.operations.length;

      h.client.unread = [_chatJson('c1')];
      h.network.reportFailure();
      h.network.reportSuccess();
      await _until(h.bloc, (s) => s.hasUnread);
      expect(h.client.operations.length, greaterThan(before));
      await h.close();
    });
  });

  group('виджеты', () {
    testWidgets(
      'в шапке кнопка со счётчиком вместо аватара, потом снова аватар',
      (tester) async {
        final h = _Harness(_signedIn());
        h.client.unread = [
          _chatJson('c1', unread: 2),
          _chatJson('t9', entityType: 'MESSAGE_THREAD'),
        ];
        h.bloc.add(const SupportUnreadStarted(watchLifecycle: false));
        await tester.pumpWidget(
          _localized(
            MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: h.authBloc),
                BlocProvider.value(value: h.bloc),
              ],
              child: Scaffold(
                appBar: AppBar(actions: const [SupportUnreadButton()]),
              ),
            ),
          ),
        );
        await _settle(tester);

        expect(find.byType(CircleAvatar), findsNothing);
        expect(find.text('3'), findsOneWidget);
        expect(
          find.byTooltip(LocaleKeys.support_unreadTooltip.tr()),
          findsOneWidget,
        );

        // Всё прочитано — на месте кнопки снова аватар с буквой почты.
        h.client.unread = const [];
        await h.repository.markRead('c1');
        await _settle(tester);
        expect(find.text('3'), findsNothing);
        expect(find.byType(CircleAvatar), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        // Bloc.close() под FakeAsync виснет — закрываем в реальной зоне.
        await tester.runAsync(h.close);
      },
    );

    testWidgets(
      'в боковой колонке — пункт со счётчиком только при непрочитанном',
      (tester) async {
        final h = _Harness(_signedIn());
        h.client.unread = [_chatJson('c1', unread: 5)];
        h.bloc.add(const SupportUnreadStarted(watchLifecycle: false));
        await tester.pumpWidget(
          _localized(
            MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: h.authBloc),
                BlocProvider.value(value: h.bloc),
                BlocProvider(create: (_) => ThemeBloc()),
              ],
              child: Scaffold(
                body: Row(
                  children: [
                    AppSidebar(
                      destinations: const [
                        SidebarDestination(
                          label: 'Главная',
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                        ),
                      ],
                      selectedIndex: 0,
                      onDestinationSelected: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(
          find.text(LocaleKeys.support_unreadTooltip.tr()),
          findsOneWidget,
        );
        expect(find.text('5'), findsOneWidget);

        h.client.unread = const [];
        await h.repository.markRead('c1');
        await _settle(tester);
        expect(find.text(LocaleKeys.support_unreadTooltip.tr()), findsNothing);
        expect(find.text('5'), findsNothing);
        await tester.runAsync(h.close);
      },
    );
  });
}
