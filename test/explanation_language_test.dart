import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/auth_repository.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/graphql_subscription_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/auth/state_management/auth/auth_bloc.dart';
import 'package:saobracaj/auth/state_management/auth/auth_state.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/test/quest/comment/comment_widget/comment_widget.dart';
import 'package:saobracaj/test/quest/comment/data/comment_repository.dart';
import 'package:saobracaj/test/quest/comment/state_management/comment_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Язык объяснения на экране вопроса — задача 1203867458890017.
///
/// Без подписки, но с включённым русским контентом объяснение в бесплатной
/// категории показывалось по-сербски, хотя конспект рядом был по-русски:
/// репозиторий объяснений смотрел на глобальный флаг `russian_content`, который
/// без гранта всегда выключен. Теперь язык выбирается по категории вопроса —
/// тем же правилом, что и у конспекта, — и переключение «РУ» перечитывает
/// объяснение на новом языке.

const _ru = 'Русское объяснение';
const _sr = 'Српско објашњење';

/// Сервер отдаёт оба фрагмента: в бесплатной категории он так и делает для
/// любого читателя, гейт остаётся клиенту.
class _BothFragmentsAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString(
      json.encode({
        'data': {
          'questionComment': {
            'status': 'READY',
            'locked': false,
            'text': {
              'items': [
                {'lang': 'RU', 'text': _ru},
                {'lang': 'SR', 'text': _sr},
              ],
            },
            'draft': null,
          },
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

class _FakeAuthBloc extends AuthBloc {
  _FakeAuthBloc(super.repository, super.subscriptions);

  @override
  AuthState get state => const AuthState(status: AuthStatus.authenticated);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late GraphqlClient client;
  late _BothFragmentsAdapter adapter;
  late FeatureFlagsRepository flags;

  setUp(() async {
    // Русский контент выбран пользователем, подписки (гранта) нет.
    SharedPreferences.setMockInitialValues({
      'feature.russian_content.enabled': true,
      'russian_content_asked': true,
    });
    storage = TokenStorage();
    adapter = _BothFragmentsAdapter();
    client = GraphqlClient(
      storage,
      dio: Dio()..httpClientAdapter = adapter,
      batchQueries: false,
    );
    flags = FeatureFlagsRepository(client, storage);
    await flags.bootstrap();
    getIt.registerFactoryParam<CommentBloc, int, String?>(
      (questionId, categoryId) => CommentBloc(
        CommentRepository(client, flags),
        NetworkStatus(),
        questionId,
        categoryId,
      ),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap(String categoryId) => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => FeatureFlagsBloc(flags)..add(FeatureFlagsStarted()),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => _FakeAuthBloc(
            AuthRepository(client, storage, AnalyticsService()),
            GraphqlSubscriptionClient(client, storage),
          ),
        ),
      ],
      child: Scaffold(
        body: CommentWidget(questionId: 7001, categoryId: categoryId),
      ),
    ),
  );

  testWidgets('в бесплатной категории без подписки объяснение по-русски', (
    tester,
  ) async {
    await tester.pumpWidget(wrap('25'));
    await tester.pumpAndSettle();

    expect(find.textContaining(_ru, findRichText: true), findsOneWidget);
    expect(find.textContaining(_sr, findRichText: true), findsNothing);
  });

  testWidgets('в платной категории без подписки — по-сербски', (tester) async {
    await tester.pumpWidget(wrap('27'));
    await tester.pumpAndSettle();

    expect(find.textContaining(_sr, findRichText: true), findsOneWidget);
    expect(find.textContaining(_ru, findRichText: true), findsNothing);
  });

  testWidgets('переключение «РУ» перечитывает объяснение на новом языке', (
    tester,
  ) async {
    await tester.pumpWidget(wrap('25'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_ru, findRichText: true), findsOneWidget);
    expect(adapter.requests, 1);

    final context = tester.element(find.byType(CommentWidget));
    context.read<FeatureFlagsBloc>().add(
      FeatureToggled(AppFeature.russianContent, false),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining(_sr, findRichText: true), findsOneWidget);
    expect(find.textContaining(_ru, findRichText: true), findsNothing);
    expect(adapter.requests, 2, reason: 'новый язык — новый запрос');

    context.read<FeatureFlagsBloc>().add(
      FeatureToggled(AppFeature.russianContent, true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(_ru, findRichText: true), findsOneWidget);
  });
}
