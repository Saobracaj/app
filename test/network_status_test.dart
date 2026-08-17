import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Адаптер-заглушка: каждый запрос либо отдаёт готовый ответ, либо бросает
/// заранее подготовленное DioException (обрыв сети, HTTP-ошибка).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<Object> responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final next = responses.removeAt(0);
    if (next is DioException) throw next;
    return ResponseBody.fromString(
      json.encode(next),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioException _dioError(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/graphql'),
  type: type,
  message: 'boom',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NetworkStatus: connectivity платформы', () {
    test('старт: без интерфейсов — offline, с Wi-Fi — online', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      final status = NetworkStatus(
        connectivityChanges: controller.stream,
        initialConnectivity: Future.value([ConnectivityResult.none]),
      );
      final seen = <bool>[];
      status.changes.listen(seen.add);

      expect(status.isOnline, isTrue, reason: 'до старта — оптимистично online');
      await status.start();
      expect(status.isOnline, isFalse);
      // События широковещательного потока доставляются асинхронно.
      await Future<void>.delayed(Duration.zero);
      expect(seen, [false]);

      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(status.isOnline, isTrue);
      expect(seen, [false, true]);

      // Повтор того же состояния не порождает событий.
      controller.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [false, true]);

      await controller.close();
      await status.dispose();
    });

    test('onReconnected срабатывает только при возврате сети', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      final status = NetworkStatus(
        connectivityChanges: controller.stream,
        initialConnectivity: Future.value([ConnectivityResult.wifi]),
      );
      var reconnects = 0;
      status.onReconnected.listen((_) => reconnects++);
      await status.start();

      controller.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(reconnects, 0);

      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(reconnects, 1);

      await controller.close();
      await status.dispose();
    });
  });

  group('NetworkStatus: отчёты GraphQL-клиента', () {
    test('обрыв соединения переводит в offline, успешный запрос — обратно', () async {
      final status = NetworkStatus();
      final adapter = _FakeAdapter([
        _dioError(DioExceptionType.connectionError),
        {
          'data': {'ok': true},
        },
      ]);
      final client = GraphqlClient(
        TokenStorage(),
        dio: Dio()..httpClientAdapter = adapter,
        networkStatus: status,
      );

      await expectLater(
        client.run('query { ok }'),
        throwsA(isA<GraphqlException>().having((e) => e.network, 'network', isTrue)),
      );
      expect(status.isOnline, isFalse);

      await client.run('query { ok }');
      expect(status.isOnline, isTrue);
    });

    test('HTTP-ошибка сервера — не offline: сервер доступен', () async {
      final status = NetworkStatus();
      final adapter = _FakeAdapter([_dioError(DioExceptionType.badResponse)]);
      final client = GraphqlClient(
        TokenStorage(),
        dio: Dio()..httpClientAdapter = adapter,
        networkStatus: status,
      );

      await expectLater(client.run('query { ok }'), throwsA(isA<GraphqlException>()));
      expect(status.isOnline, isTrue);
    });
  });

  group('NetworkStatus: пробник', () {
    test('пока линк есть, а сервер молчал — периодически пробует снова', () async {
      var probes = 0;
      late NetworkStatus status;
      status = NetworkStatus(
        probeInterval: const Duration(milliseconds: 10),
        // Как настоящий пробник: сам запрос отчитывается через клиент.
        probe: () async {
          probes++;
          if (probes >= 2) status.reportSuccess();
        },
      );

      status.reportFailure();
      expect(status.isOnline, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(probes, 2, reason: 'после успеха пробник останавливается');
      expect(status.isOnline, isTrue);
      await status.dispose();
    });

    test('без линка пробник не запускается', () async {
      var probes = 0;
      final controller = StreamController<List<ConnectivityResult>>();
      final status = NetworkStatus(
        probeInterval: const Duration(milliseconds: 10),
        probe: () async => probes++,
        connectivityChanges: controller.stream,
        initialConnectivity: Future.value([ConnectivityResult.none]),
      );
      await status.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(probes, 0);
      await controller.close();
      await status.dispose();
    });
  });
}
