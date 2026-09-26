import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/paused_simulation.dart';

/// Чем закончилась симуляция, когда её снимок стёрли.
enum SimulationOutcome {
  /// Экзамен завершён (пользователем или по таймеру) — есть результат.
  finished,

  /// Пользователь бросил симуляцию с экрана паузы — результата нет.
  abandoned,
}

/// Одно изменение снимка: новый снимок или его удаление, с пометкой, откуда
/// оно пришло — от действия на этом устройстве или с другого устройства
/// (через `SimulationSyncService`).
class PausedSimulationChange {
  const PausedSimulationChange({
    required this.snapshot,
    required this.remote,
    this.outcome,
  });

  /// Новый снимок или `null`, если он стёрт.
  final PausedSimulation? snapshot;

  /// Изменение пришло с другого устройства.
  final bool remote;

  /// Чем закончилась симуляция — только при удалении снимка; `null`, если
  /// неизвестно (другое устройство закончило её, пока это было не на связи).
  final SimulationOutcome? outcome;
}

/// Хранит снимок незавершённой симуляции экзамена ([PausedSimulation]) —
/// одну на устройство, в shared preferences.
///
/// Снимок читается в память один раз в [bootstrap] (из `main()`), поэтому
/// [current] отвечает синхронно и первый кадр главной уже знает, показывать
/// ли баннер «симуляция на паузе». Изменения публикуются в [changes] — их
/// слушает `PausedSimulationBloc`, через который снимок читают виджеты, — и
/// подробнее в [events], где видно, местное это изменение или пришедшее с
/// другого устройства: местные `SimulationSyncService` отправляет на бэкенд,
/// пришедшие — `PracticeBloc` применяет к идущей симуляции.
///
/// Рядом со снимком лежит [revision] — номер, который бэкенд присвоил
/// последнему известному нам состоянию симуляции (0 — бэкенд о ней не знает),
/// и [dirty] — признак, что здешнее изменение до бэкенда ещё не дошло. По
/// ревизии устройства и решают, кто кого догоняет: чья запись последняя, тот
/// и ведёт симуляцию (см. `SimulationSyncService`).
@lazySingleton
class PausedSimulationRepository {
  static const _key = 'practice.paused_simulation';

  /// Снимок в [_key] пришёл с другого устройства (записан через
  /// [applyRemote]). Хранится рядом со снимком: после перезапуска приложения
  /// такой снимок нельзя принять за свой и отправить на бэкенд как новый.
  static const _remoteKey = 'practice.paused_simulation.remote';

  /// Ревизия бэкенда, которой соответствует лежащий снимок (см. [revision]).
  static const _revisionKey = 'practice.paused_simulation.revision';

  /// Здешнее изменение снимка ещё не подтверждено бэкендом (см. [dirty]).
  static const _dirtyKey = 'practice.paused_simulation.dirty';

  PausedSimulation? _current;
  bool _currentIsRemote = false;
  int _revision = 0;
  bool _dirty = false;
  SharedPreferences? _prefs;
  final _changes = StreamController<PausedSimulation?>.broadcast();
  final _events = StreamController<PausedSimulationChange>.broadcast();

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Снимок незавершённой симуляции или `null`, если её нет.
  PausedSimulation? get current => _current;

  /// Текущий снимок пришёл с другого устройства и с тех пор на этом
  /// устройстве не менялся.
  bool get currentIsRemote => _current != null && _currentIsRemote;

  /// Ревизия, которую бэкенд присвоил последнему известному нам состоянию
  /// симуляции; 0 — бэкенд ни о какой симуляции этого пользователя не знает
  /// (или мы ещё ни разу с ним не сверялись).
  int get revision => _revision;

  /// Здешнее изменение (запись или удаление снимка) ещё не подтверждено
  /// бэкендом: его нужно дослать при первой возможности.
  bool get dirty => _dirty;

  /// Каждое изменение [current] (запись и удаление снимка).
  Stream<PausedSimulation?> get changes => _changes.stream;

  /// То же, с происхождением изменения и исходом при удалении.
  Stream<PausedSimulationChange> get events => _events.stream;

  /// Читает сохранённый снимок в память. Вызывается один раз из `main()`;
  /// до этого [current] отвечает `null`.
  Future<void> bootstrap() async {
    final prefs = await _store;
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      _current = PausedSimulation.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _currentIsRemote = prefs.getBool(_remoteKey) ?? false;
      _revision = prefs.getInt(_revisionKey) ?? 0;
      _dirty = prefs.getBool(_dirtyKey) ?? false;
    } catch (e) {
      // Снимок от другой версии приложения или битый — симуляцию из него не
      // собрать, лучше молча забыть, чем падать на старте.
      debugPrint('paused simulation snapshot is unreadable, dropping: $e');
      await prefs.remove(_key);
      await prefs.remove(_remoteKey);
      await prefs.remove(_revisionKey);
      await prefs.remove(_dirtyKey);
    }
  }

  /// Записывает [snapshot] как текущую незавершённую симуляцию (действие на
  /// этом устройстве).
  Future<void> save(PausedSimulation snapshot) =>
      _write(snapshot, remote: false);

  /// Стирает снимок: симуляция завершена или брошена на этом устройстве.
  Future<void> clear({
    SimulationOutcome outcome = SimulationOutcome.abandoned,
  }) => _drop(remote: false, outcome: outcome);

  /// Применяет снимок, пришедший с другого устройства: `null` — симуляция там
  /// закончилась ([outcome] — чем именно, если известно). [revision] — ревизия
  /// бэкенда, которой это состояние соответствует; без неё (вход под другим
  /// аккаунтом стирает снимок, ничего не зная о бэкенде) ревизия обнуляется.
  Future<void> applyRemote(
    PausedSimulation? snapshot, {
    SimulationOutcome? outcome,
    int revision = 0,
  }) => snapshot == null
      ? _drop(remote: true, outcome: outcome, revision: revision)
      : _write(snapshot, remote: true, revision: revision);

  /// Бэкенд принял здешнее изменение и присвоил ему [revision]: досылать
  /// больше нечего.
  Future<void> confirm(int revision) async {
    _revision = revision;
    _dirty = false;
    final prefs = await _store;
    await prefs.setInt(_revisionKey, revision);
    await prefs.setBool(_dirtyKey, false);
  }

  /// Отправить здешнее изменение не удалось (нет связи): дослать при
  /// следующей сверке.
  Future<void> markDirty() async {
    _dirty = true;
    final prefs = await _store;
    await prefs.setBool(_dirtyKey, true);
  }

  Future<void> _write(
    PausedSimulation snapshot, {
    required bool remote,
    int revision = 0,
  }) async {
    _current = snapshot;
    _currentIsRemote = remote;
    // Чужое изменение приходит с ревизией бэкенда и ничего не должно
    // дослать; здешнее ещё не подтверждено — ревизия остаётся прежней.
    if (remote) _revision = revision;
    _dirty = !remote;
    _changes.add(snapshot);
    _events.add(PausedSimulationChange(snapshot: snapshot, remote: remote));
    final prefs = await _store;
    await prefs.setString(_key, jsonEncode(snapshot.toJson()));
    await prefs.setBool(_remoteKey, remote);
    await prefs.setInt(_revisionKey, _revision);
    await prefs.setBool(_dirtyKey, _dirty);
  }

  Future<void> _drop({
    required bool remote,
    required SimulationOutcome? outcome,
    int revision = 0,
  }) async {
    if (_current == null) return;
    _current = null;
    _currentIsRemote = false;
    if (remote) _revision = revision;
    _dirty = !remote;
    _changes.add(null);
    _events.add(
      PausedSimulationChange(snapshot: null, remote: remote, outcome: outcome),
    );
    final prefs = await _store;
    await prefs.remove(_key);
    await prefs.remove(_remoteKey);
    await prefs.setInt(_revisionKey, _revision);
    await prefs.setBool(_dirtyKey, _dirty);
  }
}
