import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/models/viewer.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/push_test/data/push_test_repository.dart';
import 'package:saobracaj/push_test/models/test_push_result.dart';
import 'package:saobracaj/push_test/state_management/test_push_bloc.dart';
import 'package:saobracaj/push_test/state_management/test_push_events.dart';

/// Клиент-заглушка: запоминает переменные запроса и отдаёт заданный ответ.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage, {this.response});

  final Map<String, dynamic>? response;
  Map<String, dynamic>? lastVariables;

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    lastVariables = variables;
    return response ?? const {};
  }
}

/// Репозиторий-заглушка для блока: сеть в его тестах не участвует.
class _FakeRepository extends PushTestRepository {
  _FakeRepository(super.client, {this.result, this.failure});

  final TestPushResult? result;
  final Object? failure;
  ({String email, String? title, String? body, String? link})? lastCall;

  @override
  Future<TestPushResult> sendTestPush({
    required String email,
    String? title,
    String? body,
    String? link,
  }) async {
    lastCall = (email: email, title: title, body: body, link: link);
    if (failure != null) throw failure!;
    return result ??
        const TestPushResult(
          email: 'a@b.c',
          userId: 'u1',
          devices: 1,
          notificationId: 'n1',
        );
  }
}

/// Сессия задаётся напрямую: настоящий переход в `authenticated` тянет за собой
/// синхронизацию и фича-флаги через getIt, которых в тесте нет.
class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(super.repository, super.subscriptions, {this.viewer});

  final Viewer? viewer;

  @override
  AuthState get state => AuthState(
    status: viewer == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated,
    viewer: viewer,
  );
}

TestPushBloc _bloc(_FakeRepository repository, {String? email}) {
  final storage = TokenStorage();
  final client = _FakeClient(storage);
  return TestPushBloc(
    repository,
    _FakeAuthBloc(
      AuthRepository(client, storage),
      GraphqlSubscriptionClient(client, storage),
      viewer: email == null
          ? null
          : Viewer(
              id: 'u1',
              email: email,
              permissions: const ['send_test_push'],
            ),
    ),
  );
}

void main() {
  group('PushTestRepository', () {
    test(
      'пустые необязательные поля уходят как null, почта — без пробелов',
      () async {
        final storage = TokenStorage();
        final client = _FakeClient(
          storage,
          response: {
            'sendTestPush': {
              'email': 'user@example.com',
              'userId': 'u1',
              'devices': 2,
              'notificationId': 'n1',
            },
          },
        );

        final result = await PushTestRepository(client).sendTestPush(
          email: '  User@example.com ',
          title: '   ',
          body: 'Привет',
          link: '',
        );

        expect(client.lastVariables, {
          'email': 'User@example.com',
          'title': null,
          'body': 'Привет',
          'link': null,
        });
        expect(result.email, 'user@example.com');
        expect(result.devices, 2);
        expect(result.hasDevices, isTrue);
      },
    );

    test('ответ без устройств распознаётся как «доставлять некуда»', () async {
      final storage = TokenStorage();
      final client = _FakeClient(
        storage,
        response: {
          'sendTestPush': {
            'email': 'user@example.com',
            'userId': 'u1',
            'devices': 0,
            'notificationId': 'n1',
          },
        },
      );

      final result = await PushTestRepository(
        client,
      ).sendTestPush(email: 'user@example.com');

      expect(result.devices, 0);
      expect(result.hasDevices, isFalse);
    });
  });

  group('TestPushBloc', () {
    test('при открытии подставляет почту вошедшего администратора', () async {
      final bloc = _bloc(
        _FakeRepository(_FakeClient(TokenStorage())),
        email: 'admin@example.com',
      );

      bloc.add(TestPushOpened());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.email, 'admin@example.com');
      expect(bloc.state.canSend, isTrue);
    });

    test('без адреса с @ кнопка отправки заблокирована', () async {
      final bloc = _bloc(_FakeRepository(_FakeClient(TokenStorage())));

      bloc.add(TestPushOpened());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.email, isEmpty);
      expect(bloc.state.canSend, isFalse);

      bloc.add(TestPushEmailChanged('не-почта'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.canSend, isFalse);

      bloc.add(TestPushEmailChanged('user@example.com'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.canSend, isTrue);
    });

    test('успешная отправка кладёт результат в состояние', () async {
      final repository = _FakeRepository(
        _FakeClient(TokenStorage()),
        result: const TestPushResult(
          email: 'user@example.com',
          userId: 'u1',
          devices: 3,
          notificationId: 'n1',
        ),
      );
      final bloc = _bloc(repository, email: 'user@example.com');

      bloc.add(TestPushOpened());
      bloc.add(TestPushTitleChanged('Тест'));
      bloc.add(TestPushLinkChanged('/settings'));
      bloc.add(TestPushSubmitted());
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastCall?.email, 'user@example.com');
      expect(repository.lastCall?.title, 'Тест');
      expect(repository.lastCall?.link, '/settings');
      expect(bloc.state.sending, isFalse);
      expect(bloc.state.result?.devices, 3);
      expect(bloc.state.errorMessage, isNull);
    });

    test(
      'ошибка сервера показывается сообщением, результат сбрасывается',
      () async {
        final repository = _FakeRepository(
          _FakeClient(TokenStorage()),
          failure: GraphqlException('no user with email user@example.com'),
        );
        final bloc = _bloc(repository, email: 'user@example.com');

        bloc.add(TestPushOpened());
        bloc.add(TestPushSubmitted());
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.sending, isFalse);
        expect(bloc.state.result, isNull);
        expect(bloc.state.errorMessage, 'no user with email user@example.com');
      },
    );
  });
}
