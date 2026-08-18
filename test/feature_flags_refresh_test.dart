import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Считает обращения к `featureFlags`.
class _FlagsApi implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      json.encode({
        'data': {
          'featureFlags': {'flags': []},
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('одновременные обновления грантов делят один запрос', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _FlagsApi();
    final storage = TokenStorage();
    final repository = FeatureFlagsRepository(
      GraphqlClient(storage, dio: Dio()..httpClientAdapter = api),
      storage,
    );

    // Так это и происходит на старте: `main()` просит гранты сразу, а `AuthBloc`
    // — как только опубликована сохранённая сессия.
    await Future.wait([
      repository.refreshFromBackend(),
      repository.refreshFromBackend(),
    ]);
    expect(api.calls, 1);

    // Более поздний запрос по-прежнему уходит на сервер.
    await repository.refreshFromBackend();
    expect(api.calls, 2);
  });
}
