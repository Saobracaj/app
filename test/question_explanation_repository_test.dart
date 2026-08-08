import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/test/quest/question_features/ask_ai/data/question_explanation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays canned GraphQL responses and records the `lang` each request asked
/// for, so a test can assert the language order and that a request was skipped.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<Object> responses;
  final List<String> langs = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = Map<String, dynamic>.from(options.data as Map);
    langs.add((body['variables'] as Map)['lang'].toString());
    if (responses.isEmpty) throw StateError('unexpected request: ${langs.last}');
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

/// Fixes the study-content language: Russian on or off.
class _StubFlags extends FeatureFlagsRepository {
  _StubFlags({required this.russian})
      : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool russian;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot(
        enabled: {AppFeature.russianContent: russian},
        localOverrides: const {},
        grants: const {},
        authenticated: true,
      );
}

Map<String, dynamic> _document({String lang = 'ru'}) => {
  'questionId': 7921,
  'lang': lang,
  'version': 1,
  'summary': 'Регулируют движение полицейские в форме.',
  'explanation': 'По [чл. 2](zakon?chapter=I&chlan=2) это задача МВД.',
  'wrongChoices': [
    {'index': 0, 'text': 'инспектори', 'why': 'Не уполномочены.'},
  ],
  'sources': [
    {'type': 'zakon', 'title': 'Чл. 2', 'uri': 'zakon?chapter=I&chlan=2'},
  ],
};

Map<String, dynamic> _response(Map<String, dynamic>? document) => {
  'data': {
    'questionExplanation': document == null
        ? null
        : {'questionId': 7921, 'version': 1, 'document': document},
  },
};

DioException get _offline => DioException(
  requestOptions: RequestOptions(path: '/graphql'),
  type: DioExceptionType.connectionError,
);

QuestionExplanationRepository _repository(_FakeAdapter adapter, {bool russian = true}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return QuestionExplanationRepository(
    GraphqlClient(TokenStorage(), dio: dio),
    _StubFlags(russian: russian),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('объяснение скачивается, парсится и потом отдаётся из памяти', () async {
    final adapter = _FakeAdapter([_response(_document())]);
    final repository = _repository(adapter);

    final explanation = await repository.load(7921);
    expect(explanation, isNotNull);
    expect(explanation!.questionId, 7921);
    expect(explanation.summary, contains('полицейские'));
    expect(explanation.wrongChoices.single.why, 'Не уполномочены.');
    expect(explanation.sources.single.uri, 'zakon?chapter=I&chlan=2');

    // Повторное открытие вкладки в той же сессии — без нового запроса.
    expect(await repository.load(7921), isNotNull);
    expect(adapter.langs, ['ru']);
  });

  test('при сербском языке контента сначала спрашивается sr, затем ru', () async {
    final adapter = _FakeAdapter([_response(null), _response(_document())]);
    final repository = _repository(adapter, russian: false);

    final explanation = await repository.load(7921);
    expect(explanation, isNotNull, reason: 'русский документ — фолбэк, пока сербского нет');
    expect(adapter.langs, ['sr', 'ru']);

    // Оба ответа запомнены на сессию: и «sr нет», и русский документ.
    expect(await repository.load(7921), isNotNull);
    expect(adapter.langs, ['sr', 'ru']);
  });

  test('кэшированное объяснение открывается офлайн', () async {
    final first = _FakeAdapter([_response(_document())]);
    await _repository(first).load(7921);

    // Новый запуск (новый репозиторий, те же preferences), сеть недоступна.
    final second = _FakeAdapter([_offline, _offline]);
    final explanation = await _repository(second).load(7921);

    expect(explanation, isNotNull, reason: 'кэшированная копия должна пережить офлайн-запуск');
    expect(explanation!.questionId, 7921);
  });

  test('вопрос без объяснения — null, а не ошибка, и без повторных запросов', () async {
    final adapter = _FakeAdapter([_response(null), _response(null)]);
    final repository = _repository(adapter);

    expect(await repository.load(7921), isNull);
    expect(adapter.langs, ['ru', 'sr']);

    expect(await repository.load(7921), isNull);
    expect(adapter.langs, ['ru', 'sr']);
  });

  test('сбой без кэша пробрасывается наверх, а не превращается в «объяснения нет»', () async {
    final adapter = _FakeAdapter([_offline]);
    expect(() => _repository(adapter).load(7921), throwsA(isA<GraphqlException>()));
  });
}
