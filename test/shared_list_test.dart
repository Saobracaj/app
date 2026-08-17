import 'package:easy_localization/easy_localization.dart';
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
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/question_lists/data/question_lists_repository.dart';
import 'package:saobracaj/question_lists/data/shared_lists_repository.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:saobracaj/question_lists/models/question_list_share.dart';
import 'package:saobracaj/question_lists/presentation/shared_list_page.dart';
import 'package:saobracaj/question_lists/state_management/shared_list_bloc.dart';
import 'package:saobracaj/question_lists/state_management/shared_list_events.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Поделиться списком вопросов: экран /shared/<code> и его блок.
///
/// Проверяется модель из задачи: гость видит превью целиком, «Сохранить себе»
/// у гостя ведёт на вход и НЕ теряет код; у вошедшего — создаёт НОВЫЙ список
/// с новым id (связи с оригиналом нет); отложенный импорт доводится до конца
/// после входа; ошибки «ссылка недействительна» и «автор удалил список»
/// различаются; счётчик «N из M доступны бесплатно» честный.

class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage);

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async => const {};
}

/// Репозиторий шар с заранее заданным ответом превью; отложенный импорт —
/// настоящий (SharedPreferences с mock-хранилищем).
class _StubSharedLists extends SharedListsRepository {
  _StubSharedLists(this._result) : super(_FakeClient(TokenStorage()));

  final Object _result;

  @override
  Future<SharedListPreview> preview(String code) async {
    final r = _result;
    if (r is SharedListPreview) return r;
    throw r;
  }
}

/// Репозиторий списков: только записывает, что попросили создать.
class _RecordingLists extends QuestionListsRepository {
  _RecordingLists({this.fail = false}) : super(_FakeClient(TokenStorage()));

  final bool fail;
  final created = <QuestionList>[];

  @override
  Future<void> create(QuestionList list) async {
    if (fail) throw GraphqlException('boom');
    created.add(list);
  }
}

class _FixedAuthBloc extends AuthBloc {
  _FixedAuthBloc(this._status)
    : super(
        AuthRepository(
          _FakeClient(TokenStorage()),
          TokenStorage(),
          AnalyticsService(),
        ),
        GraphqlSubscriptionClient(_FakeClient(TokenStorage()), TokenStorage()),
      );

  final AuthStatus _status;

  @override
  AuthState get state => AuthState(status: _status);
}

class _FakeAllQuestionsBloc extends AllQuestionsBloc {
  _FakeAllQuestionsBloc(this._data);

  final QuestionsData _data;

  @override
  AllQuestionsBlocState get state =>
      AllQuestionsBlocState(questionsData: _data);
}

Question _question(int id, {String categoryId = '25'}) => Question(
  id: id,
  imageId: id,
  text: 'Питање број $id — како треба да поступи возач?',
  choicesReq: 1,
  hasImage: false,
  points: 2,
  choices: [
    for (var i = 0; i < 3; i++) Choice(text: 'Одговор $i', isCorrect: i == 0),
  ],
  categoryId: categoryId,
  subcategoryId: 1,
);

const _preview = SharedListPreview(
  code: 'ABCDEFGH',
  name: 'Тешка питања',
  color: 0xFFE53935,
  questionIds: [1, 2, 3],
  ownerDisplayName: 'Милош',
);

SharedListBloc _bloc({
  Object preview = _preview,
  AuthStatus auth = AuthStatus.authenticated,
  _RecordingLists? lists,
  String code = 'ABCDEFGH',
}) => SharedListBloc(
  code,
  _StubSharedLists(preview),
  lists ?? _RecordingLists(),
  _FixedAuthBloc(auth),
  AnalyticsService(),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(getIt.reset);

  group('SharedListBloc', () {
    test('загружает превью текущего состояния списка', () async {
      final bloc = _bloc()..add(SharedListStarted());
      await _settle();
      expect(bloc.state.loading, isFalse);
      expect(bloc.state.failure, isNull);
      expect(bloc.state.preview?.name, 'Тешка питања');
      expect(bloc.state.preview?.questionCount, 3);
      expect(bloc.state.preview?.ownerDisplayName, 'Милош');
      await bloc.close();
    });

    test(
      'вошедший: «Сохранить себе» создаёт НОВЫЙ список с новым id',
      () async {
        final lists = _RecordingLists();
        final bloc = _bloc(lists: lists)..add(SharedListStarted());
        await _settle();
        bloc.add(SharedListSaveRequested());
        await _settle();

        expect(lists.created, hasLength(1));
        final copy = lists.created.single;
        expect(copy.name, 'Тешка питања');
        expect(copy.color, 0xFFE53935);
        expect(copy.questionIds, [1, 2, 3]);
        // Свой UUID, а не код и не id оригинала.
        expect(copy.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(bloc.state.importedListId, copy.id);
        expect(bloc.state.importing, isFalse);
        await bloc.close();
      },
    );

    test('гость: «Сохранить себе» просит войти и запоминает код', () async {
      final lists = _RecordingLists();
      final bloc = _bloc(auth: AuthStatus.unauthenticated, lists: lists)
        ..add(SharedListStarted());
      await _settle();
      bloc.add(SharedListSaveRequested());
      await _settle();

      expect(lists.created, isEmpty);
      expect(bloc.state.signInRequired, isTrue);
      expect(bloc.state.importedListId, isNull);
      final pending = await SharedListsRepository(
        _FakeClient(TokenStorage()),
      ).peekPendingImport();
      expect(
        pending,
        'ABCDEFGH',
        reason: 'код не должен теряться при редиректе на вход',
      );
      await bloc.close();
    });

    test('после входа отложенный импорт доводится до конца сам', () async {
      final repo = SharedListsRepository(_FakeClient(TokenStorage()));
      // Гость нажал «сохранить» с кодом в другом регистре и с дефисом —
      // сравнение должно быть нечувствительно к этому.
      await repo.setPendingImport('abcd-efgh');
      final lists = _RecordingLists();
      final bloc = _bloc(lists: lists)..add(SharedListStarted());
      await _settle();

      expect(lists.created, hasLength(1));
      expect(bloc.state.importedListId, lists.created.single.id);
      expect(
        await repo.peekPendingImport(),
        isNull,
        reason: 'код израсходован',
      );
      await bloc.close();
    });

    test('чужой отложенный код не трогается', () async {
      final repo = SharedListsRepository(_FakeClient(TokenStorage()));
      await repo.setPendingImport('ZZZZZZZZ');
      final lists = _RecordingLists();
      final bloc = _bloc(lists: lists)..add(SharedListStarted());
      await _settle();
      expect(lists.created, isEmpty);
      expect(await repo.peekPendingImport(), 'ZZZZZZZZ');
      await bloc.close();
    });

    test(
      'ошибки различаются: ссылка недействительна / автор удалил список',
      () async {
        final invalid = _bloc(
          preview: SharedListException(SharedListFailure.linkInvalid),
        )..add(SharedListStarted());
        final deleted = _bloc(
          preview: SharedListException(SharedListFailure.listDeleted),
        )..add(SharedListStarted());
        await _settle();
        expect(invalid.state.failure, SharedListFailure.linkInvalid);
        expect(deleted.state.failure, SharedListFailure.listDeleted);
        expect(invalid.state.loading, isFalse);
        await invalid.close();
        await deleted.close();
      },
    );

    test('неудачное сохранение — одноразовый флаг, без списка', () async {
      final lists = _RecordingLists(fail: true);
      final bloc = _bloc(lists: lists)..add(SharedListStarted());
      await _settle();
      bloc.add(SharedListSaveRequested());
      await _settle();
      expect(bloc.state.importFailed, isTrue);
      expect(bloc.state.importedListId, isNull);
      bloc.add(SharedListImportHandled());
      await _settle();
      expect(bloc.state.importFailed, isFalse);
      await bloc.close();
    });
  });

  group('SharedListPage', () {
    setUpAll(() async {
      await EasyLocalization.ensureInitialized();
    });

    Widget page({
      required SharedListBloc bloc,
      AuthStatus auth = AuthStatus.authenticated,
      List<Question> questions = const [],
    }) {
      getIt.registerFactoryParam<SharedListBloc, String, dynamic>(
        (_, _) => bloc,
      );
      final storage = TokenStorage();
      final client = _FakeClient(storage);
      return EasyLocalization(
        useOnlyLangCode: true,
        supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
        fallbackLocale: const Locale('ru'),
        startLocale: const Locale('ru'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const CodegenLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(create: (_) => _FixedAuthBloc(auth)),
                BlocProvider<AllQuestionsBloc>(
                  create: (_) => _FakeAllQuestionsBloc(
                    QuestionsData(
                      categories: const [],
                      questions: questions,
                      practice: const [],
                    ),
                  ),
                ),
                BlocProvider(
                  create: (_) =>
                      FeatureFlagsBloc(FeatureFlagsRepository(client, storage)),
                ),
              ],
              child: const SharedListPage(code: 'ABCDEFGH'),
            ),
          ),
        ),
      );
    }

    testWidgets('превью: имя, автор, число вопросов, первые вопросы, кнопка', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          bloc: _bloc(),
          questions: [for (var i = 1; i <= 3; i++) _question(i)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тешка питања'), findsOneWidget);
      expect(find.text('Автор: Милош'), findsOneWidget);
      expect(find.text('Вопросов: 3'), findsOneWidget);
      expect(find.textContaining('Питање број 1'), findsOneWidget);
      expect(find.text('Сохранить себе'), findsOneWidget);
      // Все три вопроса из бесплатной категории — счётчика нет.
      expect(find.textContaining('доступны бесплатно'), findsNothing);
      // Вошедшему подсказка про вход не нужна.
      expect(find.textContaining('войдите в аккаунт'), findsNothing);
    });

    testWidgets('гость видит превью целиком и подсказку про вход', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          bloc: _bloc(auth: AuthStatus.unauthenticated),
          auth: AuthStatus.unauthenticated,
          questions: [_question(1), _question(2), _question(3)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Тешка питања'), findsOneWidget);
      expect(find.text('Сохранить себе'), findsOneWidget);
      expect(find.textContaining('войдите в аккаунт'), findsOneWidget);
    });

    testWidgets('честный счётчик: платные вопросы без подписки', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          bloc: _bloc(),
          questions: [
            _question(1),
            _question(2, categoryId: '27'),
            _question(3, categoryId: '27'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 из 3 доступны бесплатно'), findsOneWidget);
      // Блокирующего экрана нет — кнопка на месте.
      expect(find.text('Сохранить себе'), findsOneWidget);
    });

    testWidgets('«ссылка больше не действует»', (tester) async {
      await tester.pumpWidget(
        page(
          bloc: _bloc(
            preview: SharedListException(SharedListFailure.linkInvalid),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ссылка больше не действует'), findsOneWidget);
      expect(find.text('Сохранить себе'), findsNothing);
    });

    testWidgets('«автор удалил список»', (tester) async {
      await tester.pumpWidget(
        page(
          bloc: _bloc(
            preview: SharedListException(SharedListFailure.listDeleted),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Автор удалил этот список'), findsOneWidget);
      expect(find.text('Сохранить себе'), findsNothing);
    });

    testWidgets('владелец: «Это ваш список» и «Открыть список» вместо копии', (
      tester,
    ) async {
      await tester.pumpWidget(
        page(
          bloc: _bloc(
            preview: _preview.copyWith(viewerIsOwner: true, listId: 'my-id'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Это ваш список'), findsOneWidget);
      expect(find.text('Открыть список'), findsOneWidget);
      expect(find.text('Сохранить себе'), findsNothing);
    });
  });
}
