import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays canned GraphQL responses and records which operations were sent, so
/// a test can assert that the repository skipped a request entirely.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<Object> responses;
  final List<String> operations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = Map<String, dynamic>.from(options.data as Map);
    operations.add(body['query'].toString().contains('konspektCategories') ? 'catalog' : 'document');
    if (responses.isEmpty) throw StateError('unexpected request: ${operations.last}');
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

Map<String, dynamic> _document({int version = 1}) => {
  'version': version,
  'categoryId': '25',
  'categoryName': {'ru': 'Основы', 'sr': null},
  'sections': [
    {
      'id': 'intro',
      'title': {'ru': 'Раздел', 'sr': null},
      'content': {'ru': 'Текст', 'sr': null},
      'questionIds': [7921],
    },
  ],
};

Map<String, dynamic> _catalogResponse(int version) => {
  'data': {
    'konspektCategories': [
      {'categoryId': '25', 'version': version},
    ],
  },
};

Map<String, dynamic> _documentResponse({int version = 1}) => {
  'data': {
    'konspekt': {'categoryId': '25', 'version': version, 'document': _document(version: version)},
  },
};

KonspektRepository _repository(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return KonspektRepository(GraphqlClient(TokenStorage(), dio: dio));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the catalog comes from the backend and is fetched once per session', () async {
    final adapter = _FakeAdapter([_catalogResponse(1)]);
    final repository = _repository(adapter);

    expect(await repository.availableCategories(), {'25'});
    // A second read is answered from memory — no second catalog request.
    expect(await repository.availableCategories(), {'25'});
    expect(adapter.operations, ['catalog']);
  });

  test('a konspekt is downloaded, parsed and then served from memory', () async {
    final adapter = _FakeAdapter([_catalogResponse(1), _documentResponse()]);
    final repository = _repository(adapter);

    final konspekt = await repository.load('25');
    expect(konspekt, isNotNull);
    expect(konspekt!.categoryId, '25');
    expect(konspekt.sections.single.title.text, 'Раздел');

    expect((await repository.load('25'))!.categoryId, '25');
    expect(adapter.operations, ['catalog', 'document']);
  });

  test('a cached konspekt at the published version is reused without a download', () async {
    final first = _FakeAdapter([_catalogResponse(1), _documentResponse()]);
    await _repository(first).load('25');

    // A fresh repository (new launch) with the same preferences: the catalog
    // still reports v1, so the cached document is good enough.
    final second = _FakeAdapter([_catalogResponse(1)]);
    final konspekt = await _repository(second).load('25');

    expect(konspekt, isNotNull);
    expect(second.operations, ['catalog']);
  });

  test('a bumped version invalidates the cached copy', () async {
    final first = _FakeAdapter([_catalogResponse(1), _documentResponse()]);
    await _repository(first).load('25');

    final second = _FakeAdapter([_catalogResponse(2), _documentResponse(version: 2)]);
    final konspekt = await _repository(second).load('25');

    expect(konspekt, isNotNull);
    expect(second.operations, ['catalog', 'document']);
  });

  test('a cached konspekt still opens when the backend is unreachable', () async {
    final first = _FakeAdapter([_catalogResponse(1), _documentResponse()]);
    await _repository(first).load('25');

    final offline = DioException(
      requestOptions: RequestOptions(path: '/graphql'),
      type: DioExceptionType.connectionError,
    );
    final second = _FakeAdapter([offline, offline]);
    final konspekt = await _repository(second).load('25');

    expect(konspekt, isNotNull, reason: 'the cached copy must survive an offline launch');
  });

  test('without a cached copy an unreachable backend surfaces the failure', () async {
    final offline = DioException(
      requestOptions: RequestOptions(path: '/graphql'),
      type: DioExceptionType.connectionError,
    );
    final adapter = _FakeAdapter([offline, offline]);

    expect(() => _repository(adapter).load('25'), throwsA(isA<GraphqlException>()));
  });
}
