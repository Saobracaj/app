import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replays one canned GraphQL response.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.response);

  final Map<String, dynamic> response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      json.encode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Feature flags pinned for `russian_content`: [chosen] is the user's own
/// toggle (the start-up question / settings), [granted] the backend grant of
/// the pass. `russian` sets both at once.
class _StubFlags extends FeatureFlagsRepository {
  _StubFlags({bool russian = false, bool? chosen, bool? granted})
      : chosen = chosen ?? russian,
        granted = granted ?? russian,
        super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool chosen;
  final bool granted;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
        localOverrides: {AppFeature.russianContent.key: chosen},
        grants: granted ? {AppFeature.russianContent.key} : const {},
        authenticated: true,
      );
}

Map<String, dynamic> _commentResponse(List<Map<String, String>> items) => {
      'data': {
        'questionComment': {
          'status': 'READY',
          'text': {'items': items},
          'draft': null,
        },
      },
    };

CommentRepository _repository({
  bool russian = false,
  bool? chosen,
  bool? granted,
  required List<Map<String, String>> items,
}) {
  final dio = Dio()..httpClientAdapter = _FakeAdapter(_commentResponse(items));
  return CommentRepository(
    GraphqlClient(TokenStorage(), dio: dio),
    _StubFlags(russian: russian, chosen: chosen, granted: granted),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const both = [
    {'lang': 'RU', 'text': 'Русское объяснение'},
    {'lang': 'SR', 'text': 'Српско објашњење'},
  ];

  group('CommentRepository picks the study-content language', () {
    test('russian_content off → the Serbian fragment', () async {
      final details =
          await _repository(russian: false, items: both).fetchComment(1);
      expect(details!.text, 'Српско објашњење');
      // The RU-first editing source is unaffected by the display language.
      expect(details.textRu, 'Русское объяснение');
    });

    test('russian_content on → the Russian fragment', () async {
      final details =
          await _repository(russian: true, items: both).fetchComment(1);
      expect(details!.text, 'Русское объяснение');
    });

    test('missing Serbian fragment falls back to Russian', () async {
      final details = await _repository(
        russian: false,
        items: const [
          {'lang': 'RU', 'text': 'Русское объяснение'},
        ],
      ).fetchComment(1);
      expect(details!.text, 'Русское объяснение');
    });

    test('missing Russian fragment falls back to Serbian', () async {
      final details = await _repository(
        russian: true,
        items: const [
          {'lang': 'SR', 'text': 'Српско објашњење'},
        ],
      ).fetchComment(1);
      expect(details!.text, 'Српско објашњење');
    });
  });

  // Гейт — свойство вопроса: в бесплатной категории русский контент открыт
  // всем, кто его выбрал, и объяснение обязано следовать тому же правилу, что
  // и конспект рядом с ним. Раньше репозиторий смотрел на глобальный флаг,
  // который без подписки всегда выключен, — и в бесплатных категориях
  // объяснение показывалось по-сербски при включённом русском контенте.
  group('CommentRepository учитывает категорию вопроса', () {
    test('русский выбран, подписки нет, бесплатная категория → русский текст',
        () async {
      final details = await _repository(
        chosen: true,
        granted: false,
        items: both,
      ).fetchComment(1, categoryId: '25');
      expect(details!.text, 'Русское объяснение');
    });

    test('русский выбран, подписки нет, платная категория → сербский текст',
        () async {
      final details = await _repository(
        chosen: true,
        granted: false,
        items: both,
      ).fetchComment(1, categoryId: '27');
      expect(details!.text, 'Српско објашњење');
    });

    test('без категории — только глобальный флаг', () async {
      final details = await _repository(
        chosen: true,
        granted: false,
        items: both,
      ).fetchComment(1);
      expect(details!.text, 'Српско објашњење');
    });

    test('русский выключен самим пользователем → сербский и в бесплатной',
        () async {
      final details = await _repository(
        chosen: false,
        granted: true,
        items: both,
      ).fetchComment(1, categoryId: '25');
      expect(details!.text, 'Српско објашњење');
    });

    test('в бесплатной категории без русского фрагмента — сербский', () async {
      final details = await _repository(
        chosen: true,
        granted: false,
        items: const [
          {'lang': 'SR', 'text': 'Српско објашњење'},
        ],
      ).fetchComment(1, categoryId: '25');
      expect(details!.text, 'Српско објашњење');
    });
  });

  group('KonspektText.select', () {
    const bothLangs = KonspektText(ru: 'по-русски', sr: 'на српском');

    test('picks the study-content language', () {
      expect(bothLangs.select(russian: false), 'на српском');
      expect(bothLangs.select(russian: true), 'по-русски');
    });

    test('falls back to the other language while one is not authored', () {
      const ruOnly = KonspektText(ru: 'по-русски');
      const srOnly = KonspektText(sr: 'на српском');
      expect(ruOnly.select(russian: false), 'по-русски');
      expect(srOnly.select(russian: true), 'на српском');
    });
  });
}
