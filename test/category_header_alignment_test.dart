import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/categories.dart';
import 'package:saobracaj/core/presentation/wide_layout.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_button.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_catalog_bloc.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Шапка категории на широком экране (web/десктоп): кнопка конспекта должна
/// стоять у правого края колонки, а не «плавать» вслед за длиной названия.

/// Каталог конспектов без сети: конспект есть у обеих тестовых категорий.
class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<Set<String>> availableCategories() async => {'25', '26'};
}

/// Фича-флаги с выданным доступом к конспектам.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository()
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: const {},
    grants: const {'category_summaries'},
    authenticated: true,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

/// Вопросы задаются напрямую, без загрузки ассетов.
class _FakeAllQuestionsBloc extends AllQuestionsBloc {
  _FakeAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

Question _question(int id, int subcategoryId, String categoryId) => Question(
  id: id,
  imageId: id,
  text: 'Како треба да поступи возач?',
  choicesReq: 1,
  hasImage: false,
  points: 2,
  choices: [Choice(text: 'Одговор', isCorrect: true)],
  categoryId: categoryId,
  subcategoryId: subcategoryId,
);

/// Две категории с намеренно разной длиной названия: у сломанной вёрстки
/// кнопка конспекта у короткого названия уезжает влево сильнее, чем у длинного.
QuestionsData _data() => QuestionsData(
  categories: const [
    Category(
      id: '25',
      name: 'Основе безбедности саобраћаја',
      subcategories: [Subcategory(id: 1, description: 'Основне одредбе')],
    ),
    Category(
      id: '26',
      name: 'Возач',
      subcategories: [Subcategory(id: 2, description: 'Психофизички услови')],
    ),
  ],
  questions: [
    _question(1, 1, '25'),
    _question(2, 1, '25'),
    _question(3, 2, '26'),
  ],
  practice: const [],
);

Widget _app() {
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('sr'),
    saveLocale: false,
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AllQuestionsBloc>(
                create: (_) => _FakeAllQuestionsBloc(_data()),
              ),
              BlocProvider(
                create: (_) => FeatureFlagsBloc(_StubFeatureFlagsRepository()),
              ),
              BlocProvider(
                create: (_) => KonspektCatalogBloc(_StubKonspektRepository()),
              ),
            ],
            child: const Categories(wide: true),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('кнопка конспекта прижата к правому краю колонки категории', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final buttons = find.byType(KonspektButton);
    expect(buttons, findsNWidgets(2));

    // Правый край кнопки совпадает с правым краем сетки подкатегорий той же
    // категории — то есть с правым краем колонки контента.
    final grids = find.byType(ResponsiveGrid);
    expect(grids, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(
        tester.getRect(buttons.at(i)).right,
        moreOrLessEquals(tester.getRect(grids.at(i)).right, epsilon: 0.5),
        reason: 'кнопка конспекта категории №$i не у правого края',
      );
    }
  });
}
