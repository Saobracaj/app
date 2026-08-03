import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/question_lists/data/question_lists_repository.dart';
import 'package:saobracaj/question_lists/domain/list_style.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:saobracaj/question_lists/state_management/question_lists_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Клиент-заглушка: запоминает отправленные запросы и по флагу [failing]
/// изображает недоступный бэкенд.
class _FakeClient extends GraphqlClient {
  _FakeClient(super.storage, {this.result = const {}, this.failing = false});

  /// Ответ, который возвращается на любой запрос.
  final Map<String, dynamic> result;
  bool failing;

  final List<({String query, Map<String, dynamic> variables})> calls = [];

  @override
  Future<Map<String, dynamic>> run(
    String query, {
    Map<String, dynamic> variables = const {},
    bool authenticated = false,
  }) async {
    calls.add((query: query, variables: variables));
    if (failing) throw GraphqlException('offline');
    return result;
  }
}

QuestionList _list({
  String id = 'a1',
  String name = 'Знаки',
  List<int> questions = const [],
}) => QuestionList(id: id, name: name, color: 0xFF00897B, questionIds: questions);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('genListId', () {
    test('возвращает UUID версии 4 в каноническом виде', () {
      final id = genListId();
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: 'некорректный id: $id',
      );
    });

    test('не повторяется', () {
      final ids = List.generate(50, (_) => genListId());
      expect(ids.toSet().length, 50);
    });
  });

  group('QuestionListsRepository', () {
    test('создание списка публикуется сразу и уходит на бэкенд', () async {
      final client = _FakeClient(TokenStorage());
      final repo = QuestionListsRepository(client);

      final published = <List<QuestionList>>[];
      repo.changes.listen(published.add);

      await repo.create(_list(questions: const [7]));

      expect(repo.lists.single.name, 'Знаки');
      expect(repo.lists.single.questionIds, [7]);
      expect(client.calls.single.query, contains('createQuestionList'));
      expect(client.calls.single.variables['questionIds'], [7]);
      await Future<void>.delayed(Duration.zero);
      expect(published.last.single.id, 'a1');
    });

    test('ошибка бэкенда откатывает оптимистичное изменение', () async {
      final client = _FakeClient(TokenStorage(), failing: true);
      final repo = QuestionListsRepository(client);

      await expectLater(repo.create(_list()), throwsA(isA<GraphqlException>()));
      expect(repo.lists, isEmpty);
    });

    test('добавление и удаление вопроса меняет состав списка', () async {
      final client = _FakeClient(TokenStorage());
      final repo = QuestionListsRepository(client);
      await repo.create(_list(questions: const [1, 2]));

      await repo.setQuestionIncluded('a1', 3, true);
      expect(repo.lists.single.questionIds, [1, 2, 3]);

      await repo.setQuestionIncluded('a1', 1, false);
      expect(repo.lists.single.questionIds, [2, 3]);

      // Повторное добавление не создаёт дубликат.
      await repo.setQuestionIncluded('a1', 3, true);
      expect(repo.lists.single.questionIds, [2, 3]);
    });

    test('порядок вопросов сохраняется как есть', () async {
      final client = _FakeClient(TokenStorage());
      final repo = QuestionListsRepository(client);
      await repo.create(_list(questions: const [1, 2, 3]));

      await repo.setQuestions('a1', const [3, 1, 2]);
      expect(repo.lists.single.questionIds, [3, 1, 2]);
      expect(
        client.calls.last.query,
        contains('setQuestionListQuestions'),
      );
    });

    test('удаление списка убирает его из состояния', () async {
      final client = _FakeClient(TokenStorage());
      final repo = QuestionListsRepository(client);
      await repo.create(_list());

      await repo.delete('a1');
      expect(repo.lists, isEmpty);
      expect(client.calls.last.query, contains('deleteQuestionList'));
    });

    test('refresh читает списки с бэкенда', () async {
      final client = _FakeClient(
        TokenStorage(),
        result: const {
          'myQuestionLists': [
            {
              'id': 'b2',
              'name': 'Приоритет',
              'color': 123,
              'questionIds': [4, 5],
            },
          ],
        },
      );
      final repo = QuestionListsRepository(client);

      await repo.refresh();
      expect(repo.lists.single.id, 'b2');
      expect(repo.lists.single.questionIds, [4, 5]);
    });

    test('выход из аккаунта очищает списки', () async {
      final client = _FakeClient(TokenStorage());
      final repo = QuestionListsRepository(client);
      await repo.create(_list());

      await repo.onLoggedOut();
      expect(repo.lists, isEmpty);
    });

    test('списки кэшируются и переживают перезапуск без сети', () async {
      final client = _FakeClient(TokenStorage());
      final repo = QuestionListsRepository(client);
      await repo.create(_list(questions: const [9]));
      // Кэш пишется асинхронно.
      await Future<void>.delayed(Duration.zero);

      final offline = _FakeClient(TokenStorage(), failing: true);
      final restarted = QuestionListsRepository(offline);
      await restarted.bootstrap();

      expect(restarted.lists.single.id, 'a1');
      expect(restarted.lists.single.questionIds, [9]);
    });
  });

  group('QuestionListsState', () {
    test('автосписок «последние ошибки» строится из истории ответов', () {
      const state = QuestionListsState(recentMistakes: [10, 11]);
      final auto = state.autoLists.single;

      expect(auto.id, kRecentMistakesListId);
      expect(auto.isAuto, isTrue);
      expect(auto.questionIds, [10, 11]);
    });

    test('автосписки идут перед пользовательскими', () {
      final state = QuestionListsState(
        recentMistakes: const [1],
        customLists: [_list()],
      );

      expect(state.allLists.first.id, kRecentMistakesListId);
      expect(state.allLists.last.id, 'a1');
      expect(state.byId('a1')?.name, 'Знаки');
      expect(state.byId('нет такого'), isNull);
    });
  });
}
