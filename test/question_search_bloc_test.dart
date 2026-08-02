import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/questions/search/state_management/question_search_bloc.dart';
import 'package:saobracaj/questions/search/state_management/question_search_events.dart';
import 'package:saobracaj/questions/search/state_management/question_search_state.dart';

/// Собирает вопрос с минимально необходимыми полями для теста поиска.
Question _question({
  required int id,
  required int subcategoryId,
  required String text,
  List<String> choices = const [],
}) {
  return Question(
    id: id,
    imageId: id,
    text: text,
    choicesReq: 1,
    hasImage: false,
    points: 1,
    choices: choices.map((c) => Choice(text: c, isCorrect: false)).toList(),
    categoryId: '',
    subcategoryId: subcategoryId,
  );
}

/// Отправляет запрос в блок и дожидается следующего состояния.
Future<QuestionSearchState> search(QuestionSearchBloc bloc, String query) {
  final next = bloc.stream.first;
  bloc.add(QueryChanged(query));
  return next;
}

void main() {
  // Категория A содержит подкатегорию 1, категория B — подкатегорию 2.
  // Вопрос 30 намеренно лежит в подкатегории 99, которой нет ни в одной
  // отображаемой категории, — он не должен попадать в результаты поиска.
  final data = QuestionsData(
    categories: const [
      Category(id: 'a', name: 'Категория A', subcategories: [Subcategory(id: 1, description: 'подкатегория 1')]),
      Category(id: 'b', name: 'Категория B', subcategories: [Subcategory(id: 2, description: 'подкатегория 2')]),
    ],
    questions: [
      _question(id: 10, subcategoryId: 1, text: 'Красный светофор запрещает движение'),
      _question(id: 11, subcategoryId: 1, text: 'Скорость на трассе', choices: ['Красный знак', 'Синий знак']),
      _question(id: 20, subcategoryId: 2, text: 'Пешеходный переход'),
      _question(id: 30, subcategoryId: 99, text: 'Красный вопрос вне списка'),
    ],
    practice: const [],
  );

  test('пустой запрос сбрасывает результаты и делает поиск неактивным', () async {
    final bloc = QuestionSearchBloc(data);
    final state = await search(bloc, '   ');
    expect(state.isActive, isFalse);
    expect(state.groups, isEmpty);
    await bloc.close();
  });

  test('находит по тексту вопроса и по тексту вариантов ответа, группируя по категориям и игнорируя регистр', () async {
    final bloc = QuestionSearchBloc(data);
    final state = await search(bloc, 'красный');
    // Совпадают вопрос 10 (по тексту) и вопрос 11 (по варианту ответа) — оба в
    // категории A. Вопрос 30 вне отображаемых категорий не попадает; категория
    // B без совпадений не показывается.
    expect(state.groups.length, 1);
    expect(state.groups.single.categoryName, 'Категория A');
    expect(state.groups.single.questions.map((q) => q.id).toList(), [10, 11]);
    await bloc.close();
  });

  test('при отсутствии совпадений группы пусты, но поиск активен', () async {
    final bloc = QuestionSearchBloc(data);
    final state = await search(bloc, 'вертолёт');
    expect(state.isActive, isTrue);
    expect(state.groups, isEmpty);
    expect(state.matchCount, 0);
    await bloc.close();
  });

  test('matchCount считает все найденные вопросы по всем категориям', () async {
    final bloc = QuestionSearchBloc(data);
    // «знак» встречается в вариантах ответа вопроса 11 (категория A). Проверяем
    // суммарный счётчик по группам.
    final oneMatch = await search(bloc, 'знак');
    expect(oneMatch.matchCount, 1);
    // «красный» находит вопросы 10 и 11 — обе в категории A, итого два.
    final twoMatches = await search(bloc, 'красный');
    expect(twoMatches.matchCount, 2);
    await bloc.close();
  });
}
