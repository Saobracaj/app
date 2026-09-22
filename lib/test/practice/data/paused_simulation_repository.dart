import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/paused_simulation.dart';

/// Хранит снимок незавершённой симуляции экзамена ([PausedSimulation]) —
/// одну на устройство, в shared preferences.
///
/// Снимок читается в память один раз в [bootstrap] (из `main()`), поэтому
/// [current] отвечает синхронно и первый кадр главной уже знает, показывать
/// ли баннер «симуляция на паузе». Изменения публикуются в [changes] — их
/// слушает `PausedSimulationBloc`, через который снимок читают виджеты.
@lazySingleton
class PausedSimulationRepository {
  static const _key = 'practice.paused_simulation';

  PausedSimulation? _current;
  SharedPreferences? _prefs;
  final _changes = StreamController<PausedSimulation?>.broadcast();

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Снимок незавершённой симуляции или `null`, если её нет.
  PausedSimulation? get current => _current;

  /// Каждое изменение [current] (запись и удаление снимка).
  Stream<PausedSimulation?> get changes => _changes.stream;

  /// Читает сохранённый снимок в память. Вызывается один раз из `main()`;
  /// до этого [current] отвечает `null`.
  Future<void> bootstrap() async {
    final raw = (await _store).getString(_key);
    if (raw == null) return;
    try {
      _current = PausedSimulation.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // Снимок от другой версии приложения или битый — симуляцию из него не
      // собрать, лучше молча забыть, чем падать на старте.
      debugPrint('paused simulation snapshot is unreadable, dropping: $e');
      await (await _store).remove(_key);
    }
  }

  /// Записывает [snapshot] как текущую незавершённую симуляцию.
  Future<void> save(PausedSimulation snapshot) async {
    _current = snapshot;
    _changes.add(snapshot);
    await (await _store).setString(_key, jsonEncode(snapshot.toJson()));
  }

  /// Стирает снимок: симуляция завершена или брошена.
  Future<void> clear() async {
    if (_current == null) return;
    _current = null;
    _changes.add(null);
    await (await _store).remove(_key);
  }
}
