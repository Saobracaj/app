import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/data/token_storage.dart';
import '../app_language.dart';
import 'device_context.dart';

/// Вторая половина аналитики: те же события, что уходят в Google Analytics,
/// пишутся ещё и в собственный бэкенд (`trackEvents`).
///
/// Зачем дубль: GA отвечает на вопросы «сколько» и «откуда пришли», но не на
/// вопрос «что делал вот этот человек» — он знает пользователя под своим
/// псевдонимным идентификатором, отдаёт сэмплированные агрегаты и не
/// стыкуется с нашей таблицей пользователей. Собственный журнал стыкуется:
/// сервер проставляет `user_id` из токена запроса, а гостевые события
/// остаются привязанными к установке (`deviceId`).
///
/// Отправка — пачками и «как получится»: события копятся в памяти и уходят по
/// таймеру ([flushInterval]) или когда их набралось [batchSize]. Неудачная
/// отправка возвращает пачку в очередь — до [maxBuffered] событий, дальше
/// теряются самые старые: аналитика не повод расти в памяти без предела.
/// Идентификатор события генерируется на клиенте, поэтому повторная отправка
/// той же пачки ничего не задваивает.
class AnalyticsEventSink {
  AnalyticsEventSink(
    this._client,
    this._storage, {
    this.flushInterval = const Duration(seconds: 20),
    this.batchSize = 25,
    this.maxBuffered = 500,
  });

  static const _mutation = r'''
    mutation Track($events: [UserEventInput!]!) {
      trackEvents(events: $events)
    }''';

  /// Столько событий бэкенд принимает за один вызов.
  static const _maxPerCall = 500;

  final GraphqlClient _client;
  final TokenStorage _storage;

  /// Как часто уходит накопившееся.
  final Duration flushInterval;

  /// Сколько событий отправляют пачку немедленно, не дожидаясь таймера.
  final int batchSize;

  /// Потолок очереди: сверх него выбрасываются самые старые события.
  final int maxBuffered;

  final List<Map<String, Object?>> _pending = [];
  final String _sessionId = _randomId();

  Timer? _timer;
  bool _sending = false;
  String? _deviceId;
  String? _appVersion;
  String? _screen;

  /// Идентификатор запуска приложения: по нему в журнале видно, где кончилась
  /// одна сессия и началась следующая.
  String get sessionId => _sessionId;

  /// Сколько событий ждёт отправки — для тестов и отладки.
  @visibleForTesting
  int get pendingCount => _pending.length;

  /// Подтянуть идентификатор установки и версию сборки и запустить таймер.
  /// Вызывается из `main()`; до этого события копятся, но не уходят.
  Future<void> start() async {
    await _loadContext();
    _timer ??= Timer.periodic(flushInterval, (_) => flush());
  }

  /// Остановить отправку (тесты и `dispose` приложения).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Экран, на котором находится пользователь, — контекст для всех
  /// последующих событий. Это шаблон маршрута (`/question/:id`), а не путь:
  /// сырые идентификаторы едут отдельными параметрами события.
  void setScreen(String screen) => _screen = screen;

  /// Поставить событие в очередь.
  void add(String name, Map<String, Object?> params) {
    _pending.add({
      'id': _randomId(),
      'name': name,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'params': params,
      'sessionId': _sessionId,
      'platform': _platform,
      'osVersion': describeOs(),
      'locale': appLanguageCode,
      if (_screen != null) 'screen': _screen,
    });
    _dropOverflow();
    if (_pending.length >= batchSize) unawaited(flush());
  }

  /// Отправить накопившееся. Безопасно звать когда угодно: пока предыдущая
  /// отправка в полёте, вызов ничего не делает.
  Future<void> flush() async {
    if (_sending || _pending.isEmpty) return;
    _sending = true;
    final batch = _pending.take(_maxPerCall).toList(growable: false);
    _pending.removeRange(0, batch.length);
    try {
      final deviceId = _deviceId ?? await _storage.deviceId();
      _deviceId = deviceId;
      await _client.run(
        _mutation,
        variables: {
          'events': [
            for (final event in batch)
              {
                ...event,
                'deviceId': deviceId,
                if (_appVersion != null) 'appVersion': _appVersion,
              },
          ],
        },
        // Событию нужен токен, чтобы сервер приписал его аккаунту; у гостя
        // токена нет и запрос уходит анонимным. Сессию это не трогает:
        // неудача любого рода ловится ниже.
        authenticated: true,
      );
    } catch (e) {
      // Не дошло — вернуть в очередь и попробовать в следующий раз. Порядок
      // сохраняется: пачка встаёт обратно в голову.
      _pending.insertAll(0, batch);
      _dropOverflow();
      debugPrint('Analytics sink: $e');
    } finally {
      _sending = false;
    }
  }

  /// Версия сборки и идентификатор установки — те же, что уходят в заголовке
  /// `X-Device-Id`, так что журнал стыкуется с остальными таблицами.
  Future<void> _loadContext() async {
    try {
      _deviceId = await _storage.deviceId();
    } catch (e) {
      debugPrint('Analytics sink: $e');
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('Analytics sink: $e');
    }
  }

  /// Очередь длиннее [maxBuffered] — значит, связи нет давно; самые старые
  /// события отбрасываются первыми.
  void _dropOverflow() {
    final overflow = _pending.length - maxBuffered;
    if (overflow > 0) _pending.removeRange(0, overflow);
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static String _randomId() {
    final rnd = Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
