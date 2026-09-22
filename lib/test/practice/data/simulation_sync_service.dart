import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/auth_status.dart';
import '../../../auth/data/graphql_client.dart';
import '../../../auth/data/graphql_subscription_client.dart';
import '../../../auth/data/token_storage.dart';
import '../domain/paused_simulation.dart';
import 'paused_simulation_repository.dart';

/// Держит идущую симуляцию экзамена одинаковой на всех устройствах
/// пользователя (задача 1218758215704610).
///
/// Источник истины на устройстве — снимок в [PausedSimulationRepository].
/// Местные изменения снимка (действия пользователя здесь) уходят на бэкенд
/// (`setSimulation` / `clearSimulation`); изменения с других устройств
/// приходят по подписке `simulationChanged` и кладутся в тот же репозиторий
/// как чужие ([PausedSimulationRepository.applyRemote]) — открытый экран
/// симуляции (`PracticeBloc`) применяет их на лету, а если экрана нет и там
/// симуляция идёт (не на паузе), [openRequests] просит `main.dart` открыть
/// её. Гость не синхронизируется: снимок живёт только на устройстве.
///
/// Подписка живёт, пока пользователь вошёл; сокет общий с остальными
/// подписками приложения. После каждого (пере)подключения состояние сверяется
/// с бэкендом ([_pull]): что пропущено, пока связи не было, восстанавливается
/// оттуда, а что не удалось отправить отсюда — досылается.
@lazySingleton
class SimulationSyncService {
  SimulationSyncService(
    this._client,
    this._subscriptions,
    this._auth,
    this._snapshots,
    this._storage,
  );

  /// Исход, который не удалось отправить (`clearSimulation` без связи):
  /// досылается при следующей сверке, пока на бэкенде лежит наш же снимок.
  static const _pendingOutcomeKey = 'practice.simulation_sync.pending_outcome';

  final GraphqlClient _client;
  final GraphqlSubscriptionClient _subscriptions;
  final AuthRepository _auth;
  final PausedSimulationRepository _snapshots;
  final TokenStorage _storage;

  final _openRequests = StreamController<PausedSimulation>.broadcast();

  StreamSubscription<AuthStatus>? _sessionSub;
  StreamSubscription<PausedSimulationChange>? _localSub;
  StreamSubscription<GraphqlSubscriptionMessage>? _remoteSub;

  final List<PausedSimulationChange> _outbox = [];
  bool _flushing = false;
  bool _authenticated = false;
  bool _started = false;
  String? _deviceId;

  /// Симуляция идёт на другом устройстве — её нужно открыть и здесь. Слушает
  /// `main.dart`: он знает, что открыто сейчас, и открывает
  /// `/questPractice?resume=true`, если экрана симуляции ещё нет.
  Stream<PausedSimulation> get openRequests => _openRequests.stream;

  /// Начать следить за сессией и снимком. Идемпотентно; зовётся из `main()`
  /// после `PausedSimulationRepository.bootstrap()`.
  void start() {
    if (_started) return;
    _started = true;
    _localSub = _snapshots.events
        .where((change) => !change.remote)
        .listen(_enqueue);
    _sessionSub = _auth.sessionStatus.distinct().listen((status) {
      final authenticated = status == AuthStatus.authenticated;
      if (authenticated == _authenticated) return;
      _authenticated = authenticated;
      if (authenticated) {
        _attach();
      } else {
        _detach();
      }
    });
  }

  /// Открыть подписку; первое `connection_ack` (и каждое переподключение)
  /// приходит как [GraphqlSubscriptionResumed] и запускает сверку.
  void _attach() {
    _remoteSub?.cancel();
    _remoteSub = _subscriptions
        .subscribe('''
          subscription SimulationChanged {
            simulationChanged { snapshot outcome deviceId updatedAt }
          }
        ''')
        .listen(
          _onMessage,
          onError: (Object e) =>
              debugPrint('simulation sync subscription failed: $e'),
        );
  }

  /// Сессия кончилась: подписку закрываем, чужой снимок стираем — он
  /// принадлежит аккаунту, а не устройству (свой, начатый здесь, остаётся:
  /// его можно доиграть и гостем).
  void _detach() {
    _remoteSub?.cancel();
    _remoteSub = null;
    _outbox.clear();
    if (_snapshots.currentIsRemote) unawaited(_snapshots.applyRemote(null));
  }

  Future<void> _onMessage(GraphqlSubscriptionMessage message) async {
    switch (message) {
      case GraphqlSubscriptionResumed():
        await _pull();
      case GraphqlSubscriptionInterrupted():
        break;
      case GraphqlSubscriptionData(:final data):
        final raw = data['simulationChanged'];
        if (raw is! Map) return;
        final event = raw.cast<String, dynamic>();
        if (event['deviceId'] == await _ownDeviceId()) return;
        final snapshot = event['snapshot'];
        if (snapshot is Map) {
          await _applyRemote(snapshot.cast<String, dynamic>());
        } else {
          await _snapshots.applyRemote(
            null,
            outcome: _parseOutcome(event['outcome']),
          );
        }
    }
  }

  /// Сверка с бэкендом после (пере)подключения: кто кого догоняет, решает
  /// происхождение и свежесть снимков.
  ///
  ///  * на бэкенде пусто: свой снимок отправляем (симуляцию начали без связи),
  ///    чужой стираем — она закончилась, пока нас не было (исход неизвестен);
  ///  * на бэкенде наш снимок: если здесь его уже нет — досылаем исход;
  ///    если здешний свежее — досылаем его;
  ///  * на бэкенде чужой снимок: применяем, если здешний свой не свежее его.
  Future<void> _pull() async {
    final Map<String, dynamic> data;
    try {
      data = await _client.run(
        'query Simulation { simulation { snapshot deviceId updatedAt } }',
        authenticated: true,
      );
    } catch (e) {
      debugPrint('simulation sync pull failed: $e');
      return;
    }
    final raw = data['simulation'];
    final local = _snapshots.current;
    final localIsRemote = _snapshots.currentIsRemote;
    if (raw is! Map) {
      await _forgetPendingOutcome();
      if (local == null) return;
      if (localIsRemote) {
        await _snapshots.applyRemote(null);
      } else {
        _enqueue(PausedSimulationChange(snapshot: local, remote: false));
      }
      return;
    }
    final server = raw.cast<String, dynamic>();
    final serverSnapshot = _parseSnapshot(server['snapshot']);
    if (serverSnapshot == null) return;
    if (server['deviceId'] == await _ownDeviceId()) {
      if (local == null) {
        _enqueue(
          PausedSimulationChange(
            snapshot: null,
            remote: false,
            outcome: await _takePendingOutcome() ?? SimulationOutcome.abandoned,
          ),
        );
      } else if (!localIsRemote &&
          local.savedAt.isAfter(serverSnapshot.savedAt)) {
        _enqueue(PausedSimulationChange(snapshot: local, remote: false));
      }
      return;
    }
    if (local != null &&
        !localIsRemote &&
        local.savedAt.isAfter(serverSnapshot.savedAt)) {
      _enqueue(PausedSimulationChange(snapshot: local, remote: false));
      return;
    }
    await _applyRemote(server['snapshot'] as Map<String, dynamic>);
  }

  Future<void> _applyRemote(Map<String, dynamic> json) async {
    final snapshot = _parseSnapshot(json);
    if (snapshot == null) return;
    await _snapshots.applyRemote(snapshot);
    // Идёт там прямо сейчас — пусть откроется и здесь. Пауза не открывает:
    // баннер «продолжить» на главной и так есть.
    if (snapshot.pausedAt == null) _openRequests.add(snapshot);
  }

  PausedSimulation? _parseSnapshot(Object? json) {
    if (json is! Map) return null;
    try {
      return PausedSimulation.fromJson(json.cast<String, dynamic>());
    } catch (e) {
      // Снимок другой версии приложения: продолжить его здесь нельзя.
      debugPrint('simulation sync: unreadable snapshot ignored: $e');
      return null;
    }
  }

  SimulationOutcome? _parseOutcome(Object? raw) => switch (raw) {
    'FINISHED' => SimulationOutcome.finished,
    'ABANDONED' => SimulationOutcome.abandoned,
    _ => null,
  };

  /// Местное изменение — в очередь на отправку. Подряд идущие снимки
  /// схлопываются до последнего: важен текущий ход, а не каждый шаг.
  void _enqueue(PausedSimulationChange change) {
    if (!_authenticated) return;
    if (change.snapshot != null &&
        _outbox.isNotEmpty &&
        _outbox.last.snapshot != null) {
      _outbox.removeLast();
    }
    _outbox.add(change);
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty && _authenticated) {
        final change = _outbox.removeAt(0);
        await _push(change);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _push(PausedSimulationChange change) async {
    final snapshot = change.snapshot;
    try {
      if (snapshot != null) {
        await _client.run(
          r'mutation SetSimulation($snapshot: JSON!) { '
          'setSimulation(snapshot: $snapshot) { updatedAt } }',
          variables: {'snapshot': snapshot.toJson()},
          authenticated: true,
        );
      } else {
        final outcome = change.outcome ?? SimulationOutcome.abandoned;
        // Запоминаем до отправки: если связи нет, исход дошлёт сверка.
        await _rememberPendingOutcome(outcome);
        await _client.run(
          r'mutation ClearSimulation($outcome: SimulationOutcome!) { '
          'clearSimulation(outcome: $outcome) }',
          variables: {'outcome': outcome.name.toUpperCase()},
          authenticated: true,
        );
        await _forgetPendingOutcome();
      }
    } on AuthExpiredException {
      _outbox.clear();
    } catch (e) {
      // Нет связи: снимок остаётся своим в репозитории, сверка после
      // переподключения отправит его (или исход) заново.
      debugPrint('simulation sync push failed: $e');
    }
  }

  Future<String> _ownDeviceId() async =>
      _deviceId ??= await _storage.deviceId();

  Future<void> _rememberPendingOutcome(SimulationOutcome outcome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOutcomeKey, outcome.name);
  }

  Future<SimulationOutcome?> _takePendingOutcome() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_pendingOutcomeKey);
    await prefs.remove(_pendingOutcomeKey);
    return SimulationOutcome.values
        .where((outcome) => outcome.name == name)
        .firstOrNull;
  }

  Future<void> _forgetPendingOutcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOutcomeKey);
  }

  /// Для тестов: остановить всё.
  Future<void> dispose() async {
    await _sessionSub?.cancel();
    await _localSub?.cancel();
    await _remoteSub?.cancel();
    await _openRequests.close();
  }
}
