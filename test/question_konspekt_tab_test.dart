import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/test/data/quiz_preferences_repository.dart';
import 'package:saobracaj/test/quest/question_features/presentation/question_features_tabs.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_features_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A konspekt source that fails a fixed number of reads first — "offline",
/// "not entitled", "server hiccup".
class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository() : super(GraphqlClient(TokenStorage()));

  int failures = 0;

  @override
  Future<Set<String>> availableCategories() async {
    if (failures > 0) {
      failures--;
      throw GraphqlException('offline', network: true);
    }
    return {'25'};
  }

  @override
  Future<Konspekt?> load(String categoryId) async => const Konspekt(
    categoryId: '25',
    categoryName: KonspektText(ru: 'Основы'),
    sections: [
      KonspektSection(
        id: 'a',
        // Заголовки секций содержат инлайновую разметку — вкладка обязана её
        // отрисовать, а не показать звёздочки.
        title: KonspektText(ru: '*Коловоз* и трака'),
        content: KonspektText(ru: 'Правило.'),
        questionIds: [7001],
      ),
    ],
  );
}

/// Grants exactly the konspekt tab, so the panel renders that tab alone.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository() : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (f != AppFeature.categorySummaries) f.key: false,
    },
    grants: const {'category_summaries'},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late _StubKonspektRepository repository;

  setUp(() {
    repository = _StubKonspektRepository();
    getIt.registerLazySingleton<KonspektRepository>(() => repository);
    getIt.registerLazySingleton<QuizPreferencesRepository>(QuizPreferencesRepository.new);
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, void>(
      (initial, _) => QuestionFeaturesBloc(getIt(), initial),
    );
    getIt.registerFactoryParam<QuestionKonspektBloc, int, String>(
      (questionId, categoryId) => QuestionKonspektBloc(getIt(), questionId, categoryId),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap() => MaterialApp(
    home: BlocProvider(
      create: (_) => FeatureFlagsBloc(_StubFeatureFlagsRepository()),
      child: const Scaffold(
        body: QuestionFeaturesTabs(questionId: 7001, categoryId: '25'),
      ),
    ),
  );

  testWidgets('the konspekt excerpt is shown once loaded', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Правило.'), findsOneWidget);
    // Разметка заголовка отрисована, а не показана как есть.
    expect(find.text('Коловоз и трака'), findsOneWidget);
    expect(find.textContaining('*'), findsNothing);
    expect(find.text('konspekt.loadFailed'), findsNothing);
  });

  testWidgets('a failed load shows the reason and a retry that recovers', (tester) async {
    repository.failures = 1;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Without EasyLocalization in the tree tr() falls back to the raw key.
    expect(find.text('konspekt.loadFailed'), findsOneWidget);
    expect(find.text('Правило.'), findsNothing);

    await tester.tap(find.text('konspekt.retry'));
    await tester.pumpAndSettle();

    expect(find.text('Правило.'), findsOneWidget);
    expect(find.text('konspekt.loadFailed'), findsNothing);
  });
}
