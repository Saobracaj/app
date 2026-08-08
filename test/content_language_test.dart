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

/// Feature flags pinned to a fixed answer for `russian_content`.
class _StubFlags extends FeatureFlagsRepository {
  _StubFlags({required this.russian})
      : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool russian;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
        localOverrides: {AppFeature.russianContent.key: russian},
        grants: russian ? {AppFeature.russianContent.key} : const {},
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
  required bool russian,
  required List<Map<String, String>> items,
}) {
  final dio = Dio()..httpClientAdapter = _FakeAdapter(_commentResponse(items));
  return CommentRepository(
    GraphqlClient(TokenStorage(), dio: dio),
    _StubFlags(russian: russian),
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
