import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/notifications/data/notification_permissions.dart';
import 'package:saobracaj/notifications/state_management/notifications_bloc.dart';
import 'package:saobracaj/notifications/state_management/notifications_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Клиент-заглушка: сетевые вызовы в этих тестах не выполняются (пользователь
/// не авторизован), поэтому просто возвращаем пустой ответ.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async =>
      const {};
}

/// Управляемая заглушка системного разрешения на уведомления.
class _FakePermissions extends NotificationPermissions {
  _FakePermissions({
    required this.granted,
    NotificationPermissionState? afterRequest,
  }) : _afterRequest = afterRequest;

  bool granted;
  bool permanentlyDenied = false;
  final NotificationPermissionState? _afterRequest;
  bool openedSettings = false;

  @override
  Future<NotificationPermissionState> status() async =>
      NotificationPermissionState(
        granted: granted,
        permanentlyDenied: permanentlyDenied,
      );

  @override
  Future<NotificationPermissionState> request() async {
    final result = _afterRequest ??
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

NotificationsBloc _buildBloc(NotificationPermissions permissions) {
  final storage = TokenStorage();
  final repository = AuthRepository(_FakeClient(storage), storage);
  final authBloc = AuthBloc(
    repository,
    GraphqlSubscriptionClient(_FakeClient(storage), storage),
  ); // состояние по умолчанию — не авторизован
  return NotificationsBloc(repository, authBloc, permissions);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'при старте email включён по умолчанию, а push выключен, если система не даёт разрешение',
    () async {
      final bloc = _buildBloc(_FakePermissions(granted: false));
      bloc.add(NotificationsStarted());
      final state = await bloc.stream.firstWhere((s) => !s.loading);
      expect(state.emailNotifications, isTrue);
      // Разрешение в БД по умолчанию включено...
      expect(state.pushPreference, isTrue);
      // ...но система его не даёт, поэтому переключатель выключен.
      expect(state.pushEnabled, isFalse);
    },
  );

  test('push включается после выдачи системного разрешения', () async {
    final bloc = _buildBloc(
      _FakePermissions(
        granted: false,
        afterRequest:
            const NotificationPermissionState(granted: true, permanentlyDenied: false),
      ),
    );
    bloc.add(NotificationsStarted());
    await bloc.stream.firstWhere((s) => !s.loading);

    bloc.add(PushNotificationsToggled(true));
    final state = await bloc.stream.firstWhere((s) => s.pushEnabled);
    expect(state.pushEnabled, isTrue);
    expect(state.pushPreference, isTrue);
    expect(state.systemGranted, isTrue);
  });

  test(
    'если система отклонила запрос, push остаётся выключенным',
    () async {
      final bloc = _buildBloc(
        _FakePermissions(
          granted: false,
          afterRequest: const NotificationPermissionState(
            granted: false,
            permanentlyDenied: true,
          ),
        ),
      );
      bloc.add(NotificationsStarted());
      await bloc.stream.firstWhere((s) => !s.loading);

      bloc.add(PushNotificationsToggled(true));
      final state = await bloc.stream
          .firstWhere((s) => s.systemPermanentlyDenied);
      expect(state.pushEnabled, isFalse);
      expect(state.systemGranted, isFalse);
    },
  );

  test(
    'возврат в приложение (AppResumed) перечитывает системное разрешение',
    () async {
      final permissions = _FakePermissions(granted: true);
      final bloc = _buildBloc(permissions);
      bloc.add(NotificationsStarted());
      final started = await bloc.stream.firstWhere((s) => !s.loading);
      expect(started.pushEnabled, isTrue);

      // Пользователь выключил уведомления в настройках системы.
      permissions.granted = false;
      bloc.add(AppResumed());
      final resumed = await bloc.stream.firstWhere((s) => !s.systemGranted);
      expect(resumed.pushEnabled, isFalse);
    },
  );
}
