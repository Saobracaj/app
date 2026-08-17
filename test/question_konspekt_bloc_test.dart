import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/core/network/network_status.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_bloc.dart';
import 'package:saobracaj/test/quest/question_features/state_management/question_konspekt_events.dart';

class _FakeRepository implements KonspektRepository {
  _FakeRepository(this.konspekt, {this.failures = 0});

  final Konspekt? konspekt;

  /// How many of the next reads throw before the repository starts answering —
  /// stands in for "offline" / "not entitled" / "server hiccup".
  int failures;

  @override
  Future<Set<String>> availableCategories() async {
    if (failures > 0) {
      failures--;
      throw Exception('catalog unavailable');
    }
    return konspekt == null ? {} : {konspekt!.categoryId};
  }

  @override
  Future<Konspekt?> load(String categoryId) async => konspekt;
}

Konspekt _konspekt(List<KonspektSection> sections) => Konspekt(
      categoryId: '25',
      categoryName: const KonspektText(ru: 'Категория'),
      sections: sections,
    );

Future<QuestionKonspektBloc> _settled(QuestionKonspektBloc bloc) async {
  await bloc.stream.firstWhere((s) => !s.inProgress);
  return bloc;
}

void main() {
  test('a section with blocks is narrowed to the blocks mapped to the question', () async {
    final repository = _FakeRepository(_konspekt([
      const KonspektSection(
        id: 'a',
        title: KonspektText(ru: 'Секция'),
        content: KonspektText(ru: 'Вводная.\n\nПравило про 7001.\n\nПравило про 7002.'),
        blocks: [
          KonspektBlock(content: KonspektText(ru: 'Вводная.')),
          KonspektBlock(content: KonspektText(ru: 'Правило про 7001.'), questionIds: [7001]),
          KonspektBlock(content: KonspektText(ru: 'Правило про 7002.'), questionIds: [7002]),
        ],
        questionIds: [7001, 7002],
      ),
    ]));

    final bloc = await _settled(QuestionKonspektBloc(repository, NetworkStatus(), 7001, '25'));
    expect(bloc.state.sections, hasLength(1));
    expect(bloc.state.sections.single.content.text, 'Правило про 7001.');
  });

  test('a question mapped to several blocks gets them joined in order', () async {
    final repository = _FakeRepository(_konspekt([
      const KonspektSection(
        id: 'a',
        title: KonspektText(ru: 'Секция'),
        content: KonspektText(ru: 'Первое.\n\nЧужое.\n\nВторое.'),
        blocks: [
          KonspektBlock(content: KonspektText(ru: 'Первое.'), questionIds: [7001]),
          KonspektBlock(content: KonspektText(ru: 'Чужое.'), questionIds: [7002]),
          KonspektBlock(content: KonspektText(ru: 'Второе.'), questionIds: [7001]),
        ],
        questionIds: [7001, 7002],
      ),
    ]));

    final bloc = await _settled(QuestionKonspektBloc(repository, NetworkStatus(), 7001, '25'));
    expect(bloc.state.sections.single.content.text, 'Первое.\n\nВторое.');
  });

  test('a pre-blocks section falls back to its whole content', () async {
    final repository = _FakeRepository(_konspekt([
      const KonspektSection(
        id: 'a',
        title: KonspektText(ru: 'Секция'),
        content: KonspektText(ru: 'Целиком.'),
        questionIds: [7001],
      ),
      const KonspektSection(
        id: 'b',
        title: KonspektText(ru: 'Другая'),
        content: KonspektText(ru: 'Не про этот вопрос.'),
        questionIds: [7002],
      ),
    ]));

    final bloc = await _settled(QuestionKonspektBloc(repository, NetworkStatus(), 7001, '25'));
    expect(bloc.state.sections.map((s) => s.id), ['a']);
    expect(bloc.state.sections.single.content.text, 'Целиком.');
  });

  test('a broken mapping (no block lists the question) keeps the whole section', () async {
    final repository = _FakeRepository(_konspekt([
      const KonspektSection(
        id: 'a',
        title: KonspektText(ru: 'Секция'),
        content: KonspektText(ru: 'Всё.\n\nСодержимое.'),
        blocks: [
          KonspektBlock(content: KonspektText(ru: 'Всё.'), questionIds: [7002]),
          KonspektBlock(content: KonspektText(ru: 'Содержимое.'), questionIds: [7002]),
        ],
        questionIds: [7001, 7002],
      ),
    ]));

    final bloc = await _settled(QuestionKonspektBloc(repository, NetworkStatus(), 7001, '25'));
    expect(bloc.state.sections.single.content.text, 'Всё.\n\nСодержимое.');
  });

  test('a category without a konspekt is empty, not failed', () async {
    final bloc = await _settled(QuestionKonspektBloc(_FakeRepository(null), NetworkStatus(), 7001, '25'));
    expect(bloc.state.sections, isEmpty);
    expect(bloc.state.failed, isFalse, reason: 'the tab is simply hidden for such a question');
  });

  test('a failed load is reported as a failure and retries successfully', () async {
    final repository = _FakeRepository(
      _konspekt([
        const KonspektSection(
          id: 'a',
          title: KonspektText(ru: 'Секция'),
          content: KonspektText(ru: 'Целиком.'),
          questionIds: [7001],
        ),
      ]),
      failures: 1,
    );

    final bloc = await _settled(QuestionKonspektBloc(repository, NetworkStatus(), 7001, '25'));
    expect(bloc.state.failed, isTrue);
    expect(bloc.state.sections, isEmpty);

    bloc.add(QuestionKonspektRequested());
    await _settled(bloc);
    expect(bloc.state.failed, isFalse);
    expect(bloc.state.sections.single.content.text, 'Целиком.');
  });
}
