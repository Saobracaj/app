import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../auth/data/token_storage.dart';
import '../app_language.dart';
import 'device_context.dart';

/// Приёмник аналитики: события уходят в PostHog (cloud EU) его публичным
/// HTTP-API `/batch/` — по просьбе оператора это единственный приёмник,
/// Google Analytics и собственный журнал на бэкенде убраны.
///
/// Официальный SDK (`posthog_flutter`) сознательно не используется: веб-сборка
/// собирается в wasm, где JS-обвязка плагина не работает, а его нативные
/// половинки ничего не добавляют к тому, что нужно оператору. HTTP-API — это
/// тот же протокол, которым пишет и сам SDK.
///
/// Отправка — пачками и «как получится»: события копятся в памяти и уходят по
/// таймеру ([flushInterval]) или когда их набралось [batchSize]. Неудачная
/// отправка возвращает пачку в очередь — до [maxBuffered] событий, дальше
/// теряются самые старые: аналитика не повод расти в памяти без предела.
/// Идентификатор события (uuid) генерируется на клиенте, поэтому повторная
/// отправка той же пачки ничего не задваивает — PostHog дедуплицирует по нему.
class AnalyticsEventSink {
  AnalyticsEventSink(
    this._storage, {
    Dio? dio,
    this.host = 'https://eu.i.posthog.com',
    this.apiKey = 'phc_xYMQENh4bF8ccy9CYzRgTu2A7iQbfRXkj2JsohppQ9ZT',
    this.flushInterval = const Duration(seconds: 20),
    this.batchSize = 25,
    this.maxBuffered = 500,
    bool Function()? russianContent,
    Future<void> Function(Map<String, Object?> body)? postBatch,
  }) : _dio = dio ?? Dio(),
       _russianContent = russianContent,
       _postBatch = postBatch;

  /// Столько событий PostHog принимает за один вызов без риска упереться в
  /// лимит размера тела запроса.
  static const _maxPerCall = 500;

  final TokenStorage _storage;
  final Dio _dio;

  /// Адрес проекта PostHog (EU cloud) и его публичный project token. Токен
  /// клиентский по определению — он зашит в каждую установку любого
  /// PostHog-приложения и позволяет только писать события.
  final String host;
  final String apiKey;

  /// Как часто уходит накопившееся.
  final Duration flushInterval;

  /// Сколько событий отправляют пачку немедленно, не дожидаясь таймера.
  final int batchSize;

  /// Потолок очереди: сверх него выбрасываются самые старые события.
  final int maxBuffered;

  /// Включён ли русскоязычный контент — едет свойством с каждым событием.
  final bool Function()? _russianContent;

  /// Подмена транспорта в тестах; в бою — POST на `$host/batch/`.
  final Future<void> Function(Map<String, Object?> body)? _postBatch;

  final List<Map<String, Object?>> _pending = [];
  final String _sessionId = _uuidV7();

  Timer? _timer;
  bool _sending = false;
  String? _deviceId;
  String? _appVersion;
  String? _screen;
  String? _screenTitle;
  String? _userId;

  /// Идентификатор запуска приложения — `$session_id` PostHog (UUIDv7, как
  /// того требует их разбивка по сессиям).
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
  /// последующих событий. [route] — шаблон маршрута (`/question/:id`), а не
  /// путь: сырые идентификаторы едут отдельными параметрами события. [title] —
  /// человекочитаемое имя экрана для отчётов PostHog.
  void setScreen(String route, {String? title}) {
    _screen = route;
    _screenTitle = title ?? route;
  }

  /// Смена экрана — стандартное событие PostHog `$screen`, по которому его
  /// интерфейс строит пути по приложению. Имя и шаблон маршрута событие берёт
  /// из контекста, выставленного [setScreen].
  void addScreenView() => add(r'$screen', const {});

  /// Вход выполнен: гостевые события этой установки склеиваются с аккаунтом
  /// (стандартный `$identify` с `$anon_distinct_id`), дальнейшие идут от имени
  /// пользователя. [set] — свойства персоны (почта и т.п.).
  void identify(String userId, {Map<String, Object?> set = const {}}) {
    _userId = userId;
    add(r'$identify', {
      '_identify': true,
      if (set.isNotEmpty) r'$set': Map<String, Object?>.of(set),
    });
    unawaited(flush());
  }

  /// Выход: события снова гостевые, привязанные к установке.
  void clearUser() => _userId = null;

  /// Поставить событие в очередь.
  void add(String name, Map<String, Object?> params) {
    _pending.add({
      'uuid': _uuidV4(),
      'event': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      // Кто совершил событие — решается в момент события, а не отправки:
      // пачка может уйти уже после входа или выхода.
      'userId': _userId,
      'properties': {
        ...params,
        r'$session_id': _sessionId,
        r'$os': _platform,
        if (describeOs() != null) r'$os_version': describeOs(),
        'locale': appLanguageCode,
        if (_russianContent != null) 'russian_content': _russianContent(),
        if (_screen != null && name != r'$identify') ...{
          r'$screen_name': ?_screenTitle,
          'route': _screen,
        },
      },
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
      final body = <String, Object?>{
        'api_key': apiKey,
        'batch': [for (final event in batch) _message(event, deviceId)],
      };
      await (_postBatch?.call(body) ?? _send(body));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status >= 400 && status < 500 && status != 429) {
        // Пачку не приняли по существу (сломанное тело, неверный ключ) —
        // повтор даст то же самое, событиям место в логе, а не в очереди.
        debugPrint('Analytics sink: dropped batch, HTTP $status');
      } else {
        _requeue(batch, e);
      }
    } catch (e) {
      _requeue(batch, e);
    } finally {
      _sending = false;
    }
  }

  /// Не дошло — вернуть в очередь и попробовать в следующий раз. Порядок
  /// сохраняется: пачка встаёт обратно в голову.
  void _requeue(List<Map<String, Object?>> batch, Object e) {
    _pending.insertAll(0, batch);
    _dropOverflow();
    debugPrint('Analytics sink: $e');
  }

  Future<void> _send(Map<String, Object?> body) =>
      _dio.post<void>('$host/batch/', data: body);

  /// Готовое сообщение PostHog из события очереди: `distinct_id` — аккаунт,
  /// а до входа — установка; `$identify` дополнительно несёт
  /// `$anon_distinct_id`, склеивающий гостевую историю с аккаунтом.
  Map<String, Object?> _message(Map<String, Object?> event, String deviceId) {
    final properties = Map<String, Object?>.of(
      event['properties']! as Map<String, Object?>,
    );
    final identify = properties.remove('_identify') != null;
    final userId = event['userId'] as String?;
    return {
      'uuid': event['uuid'],
      'event': event['event'],
      'timestamp': event['timestamp'],
      'properties': {
        ...properties,
        'distinct_id': userId ?? deviceId,
        r'$device_id': deviceId,
        if (identify) r'$anon_distinct_id': deviceId,
        if (_appVersion != null) r'$app_version': _appVersion,
        r'$lib': 'saobracaj-app',
      },
    };
  }

  /// Версия сборки и идентификатор установки — те же, что уходят в заголовке
  /// `X-Device-Id`, так что события стыкуются с остальными данными.
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

  /// Значения, которые просил оператор: `web` / `android` / `ios` (на
  /// остальных настольных платформах — их имя).
  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  static final _random = Random();

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return _format(bytes);
  }

  /// `$session_id` PostHog обязан быть UUIDv7 — время в старших битах.
  static String _uuidV7() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    for (var i = 0; i < 6; i++) {
      bytes[i] = (millis >> (8 * (5 - i))) & 0xff;
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x70;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return _format(bytes);
  }

  static String _format(List<int> bytes) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
