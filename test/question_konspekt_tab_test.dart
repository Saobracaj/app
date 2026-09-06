import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_inline_text.dart';
import 'package:saobracaj/subscription/presentation/paywall.dart';
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

  /// The text of the one section about the question; `null` models what the
  /// backend's preview sends for a section outside the sample — a title with
  /// an empty content object.
  String? content = 'Правило.';

  @override
  Future<Set<String>> availableCategories() async {
    if (failures > 0) {
      failures--;
      throw GraphqlException('offline', network: true);
    }
    return {'25', '27'};
  }

  @override
  Future<Konspekt?> load(String categoryId) async => Konspekt(
    categoryId: categoryId,
    categoryName: const KonspektText(ru: 'Основы'),
    sections: [
      KonspektSection(
        id: 'a',
        // Заголовки секций содержат инлайновую разметку — вкладка обязана её
        // отрисовать, а не показать звёздочки.
        title: const KonspektText(ru: '*Коловоз* и трака'),
        content: KonspektText(ru: content),
        questionIds: const [7001],
      ),
    ],
  );
}

/// Grants exactly the konspekt tab, so the panel renders that tab alone —
/// or, without the grant, leaves it *locked* in a paid category.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository({this.granted = true})
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool granted;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {
      for (final f in AppFeature.values)
        if (f != AppFeature.categorySummaries) f.key: false,
    },
    grants: granted ? const {'category_summaries'} : const {},
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
    getIt.registerLazySingleton<QuizPreferencesRepository>(
      QuizPreferencesRepository.new,
    );
    getIt.registerFactoryParam<QuestionFeaturesBloc, AppFeature?, void>(
      (initial, _) => QuestionFeaturesBloc(getIt(), initial),
    );
    getIt.registerFactoryParam<QuestionKonspektBloc, int, String>(
      (questionId, categoryId) => QuestionKonspektBloc(
        getIt(),
        NetworkStatus(),
        questionId,
        categoryId,
      ),
    );
  });

  tearDown(() => getIt.reset());

  Widget wrap({String categoryId = '25', bool granted = true}) => MaterialApp(
    home: BlocProvider(
      create: (_) =>
          FeatureFlagsBloc(_StubFeatureFlagsRepository(granted: granted)),
      child: Scaffold(
        body: QuestionFeaturesTabs(questionId: 7001, categoryId: categoryId),
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

  testWidgets('a failed load shows the reason and a retry that recovers', (
    tester,
  ) async {
    repository.failures = 1;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Without EasyLocalization in the tree tr() falls back to the raw key.
    // A *network* failure reads "no network", not the generic konspekt error.
    expect(find.text('network.noConnection'), findsOneWidget);
    expect(find.text('Правило.'), findsNothing);

    await tester.tap(find.text('network.retry'));
    await tester.pumpAndSettle();

    expect(find.text('Правило.'), findsOneWidget);
    expect(find.text('network.noConnection'), findsNothing);
  });

  // Гейт конспекта на вкладке вопроса устроен как гейт объяснения: категория 27
  // платная, гранта нет — вкладка показывает начало раздела про этот вопрос
  // под размытием и карточку с предложением подписки, а не только названия.
  testWidgets('a locked konspekt previews the excerpt under the offer', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(categoryId: '27', granted: false));
    await tester.pumpAndSettle();

    expect(find.byType(LockedContentCard), findsOneWidget);
    // Превью — настоящий текст раздела и его заголовок, размеченный.
    expect(find.text('Правило.'), findsOneWidget);
    expect(find.text('Коловоз и трака'), findsOneWidget);
    // Without EasyLocalization in the tree tr() falls back to the raw key.
    expect(
      find.textContaining('subscription.lockedKonspektBody'),
      findsOneWidget,
    );
    // Раз текст виден, список разделов в карточке не дублируется.
    expect(find.textContaining('subscription.lockedSections'), findsNothing);
    // Ссылки на полный конспект под замком нет — туда ведёт кнопка карточки.
    expect(find.text('konspekt.openFull'), findsNothing);
  });

  // Раздел, для которого превью пустое (документ до блоков, блок вне выборки
  // бэкенда), карточка только называет — как раньше.
  testWidgets('a locked konspekt without text names the sections', (
    tester,
  ) async {
    repository.content = null;
    await tester.pumpWidget(wrap(categoryId: '27', granted: false));
    await tester.pumpAndSettle();

    expect(find.byType(LockedContentCard), findsOneWidget);
    expect(find.textContaining('subscription.lockedSections'), findsOneWidget);
    expect(find.byType(KonspektInlineText), findsNothing);
  });

  // Полная копия из кэша не должна просочиться под размытие целиком: вкладка
  // режет фрагмент сама, по правилу бэкенда.
  testWidgets('a locked konspekt cuts a full excerpt to its opening', (
    tester,
  ) async {
    repository.content =
        'Первый абзац.\n\nВторой абзац, которого без подписки быть не должно.';
    await tester.pumpWidget(wrap(categoryId: '27', granted: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('Первый абзац.'), findsOneWidget);
    expect(find.textContaining('Второй абзац'), findsNothing);
  });
}
