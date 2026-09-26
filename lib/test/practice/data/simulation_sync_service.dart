import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/auth_status.dart';
import '../../../auth/data/graphql_client.dart';
import '../../../auth/data/graphql_subscription_client.dart';
import '../../../auth/data/jwt.dart';
import '../../../auth/data/token_storage.dart';
import '../domain/paused_simulation.dart';
import 'paused_simulation_repository.dart';

/// Держит идущую симуляцию экзамена одинаковой на всех устройствах
/// пользователя (задача 1218758215704610).
///
/// Источник истины на устройстве — снимок в [PausedSimulationRepository].
/// Местные изменения снимка (действия пользователя здесь) уходят на бэкенд
/// (`setSimulation` / `endSimulation`); изменения с других устройств приходят
/// по подписке `simulationChanged` и кладутся в тот же репозиторий как чужие
/// ([PausedSimulationRepository.applyRemote]) — открытый экран симуляции
/// (`PracticeBloc`) применяет их на лету, а если экрана нет и там симуляция
/// идёт (не на паузе), [openRequests] просит `main.dart` открыть её. Гость не
/// синхронизируется: снимок живёт только на устройстве.
///
/// **Кто пишет, решает ревизия.** У состояния на бэкенде есть номер, который
/// растёт с каждой принятой записью. Отправляя снимок, устройство сообщает
/// ревизию, на которой этот снимок построен ([PausedSimulationRepository
/// .revision]): запись проходит, только пока она на бэкенде и лежит, а иначе
/// отклоняется — значит, пока мы собирались, симуляцию повёл кто-то другой, и
/// его состояние нам и возвращают. Пришедшее изменение применяется только
/// когда его ревизия новее известной нам. Так устройство, на котором
/// пользователь только что действовал, ведёт симуляцию (у него самая свежая
/// ревизия), остальные её воспроизводят, а эхо собственной записи отбрасывается
/// само — узнавать себя не нужно. По `deviceId` это и не получалось: две
/// вкладки одного браузера делят один id (он лежит в shared preferences, то
/// есть в localStorage), и вторая вкладка выбрасывала все события первой как
/// собственное эхо.
///
/// Подписка живёт, пока пользователь вошёл; сокет общий с остальными
/// подписками приложения. После каждого (пере)подключения состояние сверяется
/// с бэкендом ([_pull]): что пропущено, пока связи не было, восстанавливается
/// оттуда, а что не удалось отправить отсюда ([PausedSimulationRepository
/// .dirty]) — досылается. Возврат приложения из фона переоткрывает сокет сам:
/// сокет, умерший, пока приложение спало, об этом не сообщает, и без этого
/// телефон узнавал бы о ходе на вебе только с очередным таймером повтора (или
/// никогда).
///
/// Снимок принадлежит аккаунту, а не устройству: рядом с ним лежит id
/// пользователя, под которым он записан ([_ownerKey]). Вход под другим
/// аккаунтом такой снимок стирает — иначе экзамен одного аккаунта уезжал бы во
/// второй и появлялся на чужих устройствах (на одном браузере аккаунты меняют
/// часто). Снимок, начатый гостем (владельца нет), наоборот, достаётся
/// вошедшему: играли без входа, вошли — продолжаем.
@lazySingleton
class SimulationSyncService {
  SimulationSyncService(
    this._client,
    this._subscriptions,
    this._auth,
    this._snapshots,
    this._storage,
  );

  /// Исход, который не удалось отправить (`endSimulation` без связи):
  /// досылается при следующей сверке, пока на бэкенде лежит наш же снимок.
  static const _pendingOutcomeKey = 'practice.simulation_sync.pending_outcome';

  /// Аккаунт, которому принадлежит лежащий на устройстве снимок (id
  /// пользователя); значения нет — снимок начат гостем.
  static const _ownerKey = 'practice.simulation_sync.owner';

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

  /// Ревизия, которую должна получить отправляемая прямо сейчас запись (на
  /// единицу больше той, на которой она построена). Событие с этой ревизией —
  /// эхо нашей записи, пришедшее раньше ответа на неё.
  int? _awaitedRevision;

  AppLifecycleListener? _lifecycle;
  bool _hidden = false;

  /// Симуляция идёт на другом устройстве — её нужно открыть и здесь. Слушает
  /// `main.dart`: он знает, что открыто сейчас, и открывает
  /// `/questPractice?resume=true`, если экрана симуляции ещё нет.
  Stream<PausedSimulation> get openRequests => _openRequests.stream;

  /// Начать следить за сессией и снимком. Идемпотентно; зовётся из `main()`
  /// после `PausedSimulationRepository.bootstrap()`. [watchLifecycle] —
  /// переоткрывать сокет при возврате приложения из фона (в тестах без
  /// биндинга виджетов — выключить).
  void start({bool watchLifecycle = true}) {
    if (_started) return;
    _started = true;
    if (watchLifecycle) {
      // Возврат после «спрятали» (фон на телефоне, скрытая вкладка) —
      // не после любого `inactive → resumed` (системный диалог поверх).
      // И onHide, и onPause: без известного предыдущего состояния слушатель
      // не достраивает промежуточные переходы и зовёт только конечный.
      _lifecycle = AppLifecycleListener(
        onHide: () => _hidden = true,
        onPause: () => _hidden = true,
        onResume: () {
          if (!_hidden) return;
          _hidden = false;
          unawaited(_onForeground());
        },
      );
    }
    _localSub = _snapshots.events
        .where((change) => !change.remote)
        .listen(_enqueue);
    _sessionSub = _auth.sessionStatus.distinct().listen((status) {
      final authenticated = status == AuthStatus.authenticated;
      if (authenticated == _authenticated) return;
      _authenticated = authenticated;
      if (authenticated) {
        unawaited(_attach());
      } else {
        _detach();
      }
    });
  }

  /// Приложение вернулось из фона: сокет переоткрывается, и подписка после
  /// `connection_ack` сверяется с бэкендом как после любого переподключения.
  Future<void> _onForeground() async {
    if (!_authenticated) return;
    await _subscriptions.reconnect();
  }

  /// Открыть подписку; первое `connection_ack` (и каждое переподключение)
  /// приходит как [GraphqlSubscriptionResumed] и запускает сверку.
  Future<void> _attach() async {
    await _claimSnapshotOwnership();
    if (!_authenticated) return;
    _remoteSub?.cancel();
    _remoteSub = _subscriptions
        .subscribe('''
          subscription SimulationChanged {
            simulationChanged { snapshot outcome revision }
          }
        ''')
        .listen(
          _onMessage,
          onError: (Object e) =>
              debugPrint('simulation sync subscription failed: $e'),
        );
  }

  /// Сверяет владельца лежащего снимка с вошедшим аккаунтом: чужой снимок
  /// стирает (молча — на бэкенд ничего не уходит, он не наш), снимок гостя
  /// присваивает этому аккаунту.
  Future<void> _claimSnapshotOwnership() async {
    final user = jwtSubject(await _storage.accessToken);
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_ownerKey);
    if (owner == user) return;
    // Экзамен другого аккаунта: на этом устройстве ему делать нечего.
    if (owner != null && _snapshots.current != null) {
      await _snapshots.applyRemote(null);
    }
    await prefs.setString(_ownerKey, user);
  }

  /// Запоминает, что лежащий снимок принадлежит текущему аккаунту.
  Future<void> _rememberOwner() async {
    final user = jwtSubject(await _storage.accessToken);
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, user);
  }

  /// Сессия кончилась: подписку закрываем, чужой снимок стираем — он
  /// принадлежит аккаунту, а не устройству (свой, начатый здесь, остаётся:
  /// его можно доиграть и гостем).
  void _detach() {
    _remoteSub?.cancel();
    _remoteSub = null;
    _outbox.clear();
    _awaitedRevision = null;
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
        final revision = _revisionOf(event['revision']);
        // Не новее того, что мы знаем (или эхо записи, ответ на которую ещё
        // в пути) — мимо: ведёт симуляцию тот, чья ревизия свежее.
        if (revision != null &&
            (revision <= _snapshots.revision ||
                revision == _awaitedRevision)) {
          return;
        }
        final at = revision ?? _snapshots.revision;
        final snapshot = event['snapshot'];
        if (snapshot is Map) {
          await _applyRemote(snapshot.cast<String, dynamic>(), at);
        } else {
          await _snapshots.applyRemote(
            null,
            outcome: _parseOutcome(event['outcome']),
            revision: at,
          );
        }
    }
  }

  /// Сверка с бэкендом после (пере)подключения: у кого свежее состояние, тот
  /// и ведёт симуляцию.
  ///
  ///  * на бэкенде ничего никогда не было: свой снимок отправляем (симуляцию
  ///    начали без связи), чужой стираем;
  ///  * на бэкенде ревизия свежее нашей: применяем — мы отстали (и если это
  ///    «надгробие», симуляция там окончена, заканчиваем её и здесь);
  ///  * на бэкенде наша ревизия: досылаем то, что не успели отправить
  ///    ([PausedSimulationRepository.dirty]).
  ///
  /// Исключение — своя симуляция, начатая здесь после того, как на бэкенде всё
  /// кончилось: надгробие *другой* попытки не повод стирать начатый здесь
  /// экзамен, его мы отправляем.
  Future<void> _pull() async {
    final Map<String, dynamic> data;
    try {
      data = await _client.run(
        'query Simulation { '
        'simulation { snapshot outcome revision } }',
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
      // Бэкенд не знает ни о какой симуляции этого пользователя.
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
    final revision = _revisionOf(server['revision']);
    final serverSnapshot = _parseSnapshot(server['snapshot']);
    final outcome = _parseOutcome(server['outcome']);
    if (revision != null && revision <= _snapshots.revision) {
      // Мы и так знаем это состояние; осталось дослать своё, если было что.
      await _flushPending(local, localIsRemote);
      return;
    }
    final at = revision ?? _snapshots.revision;
    if (outcome != null) {
      // Надгробие: пока нас не было, симуляцию там закончили.
      await _forgetPendingOutcome();
      final ownAttemptGoesOn =
          local != null &&
          !localIsRemote &&
          serverSnapshot != null &&
          !_sameAttempt(local, serverSnapshot);
      if (ownAttemptGoesOn) {
        // Свой экзамен, начатый здесь после того конца, — продолжается.
        _enqueue(PausedSimulationChange(snapshot: local, remote: false));
        return;
      }
      await _snapshots.applyRemote(null, outcome: outcome, revision: at);
      return;
    }
    if (serverSnapshot == null) return;
    await _applyRemote(server['snapshot'] as Map<String, dynamic>, at);
  }

  /// Досылает изменение, которое не дошло до бэкенда (связи не было в момент
  /// действия), когда на бэкенде всё ещё наша ревизия.
  Future<void> _flushPending(
    PausedSimulation? local,
    bool localIsRemote,
  ) async {
    if (!_snapshots.dirty) return;
    if (local != null && !localIsRemote) {
      _enqueue(PausedSimulationChange(snapshot: local, remote: false));
    } else if (local == null) {
      _enqueue(
        PausedSimulationChange(
          snapshot: null,
          remote: false,
          outcome: await _takePendingOutcome() ?? SimulationOutcome.abandoned,
        ),
      );
    }
  }

  /// Один и тот же экзамен: по id попытки, а у снимков без него (старая
  /// версия) — по моменту старта.
  bool _sameAttempt(PausedSimulation a, PausedSimulation b) {
    final ida = a.attemptUuid;
    final idb = b.attemptUuid;
    if (ida != null && idb != null) return ida == idb;
    return a.startedAt == b.startedAt;
  }

  Future<void> _applyRemote(Map<String, dynamic> json, int revision) async {
    final snapshot = _parseSnapshot(json);
    if (snapshot == null) return;
    await _rememberOwner();
    await _snapshots.applyRemote(snapshot, revision: revision);
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

  /// Ревизия из ответа бэкенда, или `null`, если её там нет — бэкенд ещё не
  /// обновлён (порядок деплоя: сперва он, потом клиент). Тогда порядок не
  /// проверяется вовсе: лучше применить чужой ход, чем не применить никакой.
  int? _revisionOf(Object? raw) => switch (raw) {
    final int revision => revision,
    final String revision => int.tryParse(revision),
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
    final base = _snapshots.revision;
    _awaitedRevision = base + 1;
    try {
      final Map<String, dynamic> data;
      if (snapshot != null) {
        data = await _client.run(
          r'mutation SetSimulation($snapshot: JSON!, $baseRevision: Int!) { '
          r'setSimulation(snapshot: $snapshot, baseRevision: $baseRevision) '
          r'{ accepted snapshot outcome revision } }',
          variables: {'snapshot': snapshot.toJson(), 'baseRevision': base},
          authenticated: true,
        );
        await _rememberOwner();
        await _onWriteResult(data['setSimulation']);
      } else {
        final outcome = change.outcome ?? SimulationOutcome.abandoned;
        // Запоминаем до отправки: если связи нет, исход дошлёт сверка.
        await _rememberPendingOutcome(outcome);
        data = await _client.run(
          r'mutation EndSimulation($outcome: SimulationOutcome!, '
          r'$baseRevision: Int!) { '
          r'endSimulation(outcome: $outcome, baseRevision: $baseRevision) '
          r'{ accepted snapshot outcome revision } }',
          variables: {
            'outcome': outcome.name.toUpperCase(),
            'baseRevision': base,
          },
          authenticated: true,
        );
        await _forgetPendingOutcome();
        await _onWriteResult(data['endSimulation']);
      }
    } on AuthExpiredException {
      _outbox.clear();
    } catch (e) {
      // Нет связи: изменение остаётся неотправленным, сверка после
      // переподключения дошлёт его.
      debugPrint('simulation sync push failed: $e');
      await _snapshots.markDirty();
    } finally {
      _awaitedRevision = null;
    }
  }

  /// Ответ на запись: принята — запоминаем присвоенную ревизию; отклонена —
  /// пока мы собирались, симуляцию повёл кто-то другой, и вернули нам его
  /// состояние: отдаём ему ведение и применяем присланное.
  Future<void> _onWriteResult(Object? raw) async {
    if (raw is! Map) return;
    final result = raw.cast<String, dynamic>();
    final revision = _revisionOf(result['revision']);
    if (result['accepted'] == true) {
      if (revision != null) await _snapshots.confirm(revision);
      return;
    }
    _outbox.clear();
    if (revision == null || revision <= _snapshots.revision) return;
    final snapshot = result['snapshot'];
    final outcome = _parseOutcome(result['outcome']);
    if (snapshot is Map && outcome == null) {
      await _applyRemote(snapshot.cast<String, dynamic>(), revision);
    } else {
      await _snapshots.applyRemote(
        null,
        outcome: outcome ?? SimulationOutcome.abandoned,
        revision: revision,
      );
    }
  }

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
    _lifecycle?.dispose();
    await _sessionSub?.cancel();
    await _localSub?.cancel();
    await _remoteSub?.cancel();
    await _openRequests.close();
  }
}
