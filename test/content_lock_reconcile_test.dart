import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Записывает, что репозитории контента сообщили о вердикте бэкенда.
class _RecordingFlags extends FeatureFlagsRepository {
  _RecordingFlags() : super(GraphqlClient(TokenStorage()), TokenStorage());

  final verdicts = <(AppFeature, String?, bool)>[];

  @override
  Future<void> reconcileContentLock(
    AppFeature feature,
    String? categoryId, {
    required bool locked,
  }) async {
    verdicts.add((feature, categoryId, locked));
  }
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  final List<Object> responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (responses.isEmpty) throw StateError('лишний запрос');
    return ResponseBody.fromString(
      json.encode(responses.removeAt(0)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GraphqlClient _client(_FakeAdapter adapter) =>
    GraphqlClient(TokenStorage(), dio: Dio()..httpClientAdapter = adapter);

Map<String, dynamic> _konspektResponse({required bool locked}) => {
  'data': {
    'konspekt': {
      'categoryId': '30',
      'version': 1,
      'locked': locked,
      'document': {
        'version': 1,
        'categoryId': '30',
        'categoryName': {'ru': 'Знаки', 'sr': null},
        'sections': [
          {
            'id': 's1',
            'title': {'ru': 'Раздел', 'sr': null},
            'content': {'ru': 'Текст', 'sr': null},
            'questionIds': [10182],
          },
        ],
      },
    },
  },
};

const _catalogResponse = {
  'data': {
    'konspektCategories': [
      {'categoryId': '30', 'version': 1},
    ],
  },
};

Map<String, dynamic> _commentResponse({required bool locked}) => {
  'data': {
    'questionComment': {
      'status': 'READY',
      'locked': locked,
      'text': {
        'items': [
          {'lang': 'SR', 'text': 'Objašnjenje.'},
        ],
      },
      'draft': null,
    },
  },
};

/// Ответ бэкенда о контенте — истина, которую кэш грантов обязан предсказывать:
/// репозитории конспекта и объяснения передают его вердикт во флаги.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('конспект: вердикт о замке уходит во флаги', () async {
    final flags = _RecordingFlags();
    final repository = KonspektRepository(
      _client(_FakeAdapter([_catalogResponse, _konspektResponse(locked: true)])),
      flags: flags,
    );

    final konspekt = await repository.load('30');

    expect(konspekt?.locked, isTrue);
    expect(flags.verdicts, [(AppFeature.categorySummaries, '30', true)]);
  });

  test('конспект: полный документ — вердикт «открыто»', () async {
    final flags = _RecordingFlags();
    final repository = KonspektRepository(
      _client(_FakeAdapter([_catalogResponse, _konspektResponse(locked: false)])),
      flags: flags,
    );

    await repository.load('30');

    expect(flags.verdicts, [(AppFeature.categorySummaries, '30', false)]);
  });

  test('конспект: без флагов репозиторий работает как раньше', () async {
    final repository = KonspektRepository(
      _client(_FakeAdapter([_catalogResponse, _konspektResponse(locked: false)])),
    );

    expect((await repository.load('30'))?.categoryId, '30');
  });

  test('объяснение: вердикт о замке уходит во флаги', () async {
    final flags = _RecordingFlags();
    final repository = CommentRepository(
      _client(_FakeAdapter([_commentResponse(locked: false)])),
      flags,
    );

    final details = await repository.fetchComment(10182, categoryId: '30');

    expect(details?.locked, isFalse);
    expect(flags.verdicts, [(AppFeature.questionComments, '30', false)]);
  });

  test('объяснение: превью — вердикт «заперто»', () async {
    final flags = _RecordingFlags();
    final repository = CommentRepository(
      _client(_FakeAdapter([_commentResponse(locked: true)])),
      flags,
    );

    await repository.fetchComment(10182, categoryId: '30');

    expect(flags.verdicts, [(AppFeature.questionComments, '30', true)]);
  });
}
