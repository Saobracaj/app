import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/dictionary/dict_links.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_events.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/test/quest/presentation/answer_option_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Тумблер «Подсветка определений из закона» (`law_definitions_highlight`) на
/// экране «Функции»: пока он включён, термины в тексте вопроса и вариантов
/// ответа становятся ссылками на определения (`dict/…`), после выключения —
/// остаются обычным текстом.

/// Флаги с заданным значением локального тумблера подсветки. Фича гостевая,
/// поэтому решает только сам тумблер — ни сессия, ни гранты не нужны.
class _StubFlags extends FeatureFlagsRepository {
  _StubFlags({required this.highlight})
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool highlight;

  @override
  FeatureFlagsSnapshot get snapshot => _snapshot(highlight);

  @override
  Stream<FeatureFlagsSnapshot> get changes => const Stream.empty();
}

FeatureFlagsSnapshot _snapshot(bool highlight) => FeatureFlagsSnapshot.resolve(
  localOverrides: {AppFeature.lawDefinitionsHighlight.key: highlight},
  grants: const {},
  authenticated: false,
);

/// Текст, который каждый Markdown на экране получил на вход.
List<String> _markdownData(WidgetTester tester) => [
  for (final w in tester.widgetList<Markdown>(find.byType(Markdown))) w.data,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // «Возило» и «насеље» — термины внутреннего словаря (см. dictionary_test).
  const questionText = 'Возило се креће кроз насеље';
  const choiceText = 'Возач управља возилом';

  final question = Question(
    id: 1,
    imageId: 0,
    text: questionText,
    choicesReq: 1,
    hasImage: false,
    points: 2,
    choices: const [Choice(text: choiceText, isCorrect: true)],
    categoryId: '25',
    subcategoryId: 1,
  );

  Widget wrap(FeatureFlagsBloc bloc, Widget child) => MaterialApp(
    home: BlocProvider.value(
      value: bloc,
      child: Scaffold(body: ListView(children: [child])),
    ),
  );

  testWidgets('с включённым тумблером термины ответа — ссылки на определения', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FeatureFlagsBloc(_StubFlags(highlight: true)),
        AnswerOptionCard(
          choice: question.choices.first,
          selected: false,
          revealed: false,
          showTranslation: false,
        ),
      ),
    );

    expect(_markdownData(tester).single, contains('(dict/'));
  });

  testWidgets('с выключенным тумблером текст ответа остаётся без ссылок', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FeatureFlagsBloc(_StubFlags(highlight: false)),
        AnswerOptionCard(
          choice: question.choices.first,
          selected: false,
          revealed: false,
          showTranslation: false,
        ),
      ),
    );

    expect(_markdownData(tester).single, choiceText);
  });

  testWidgets('переключение тумблера сразу перерисовывает текст', (
    tester,
  ) async {
    final bloc = FeatureFlagsBloc(_StubFlags(highlight: true));
    await tester.pumpWidget(
      wrap(
        bloc,
        AnswerOptionCard(
          choice: question.choices.first,
          selected: false,
          revealed: false,
          showTranslation: false,
        ),
      ),
    );
    expect(_markdownData(tester).single, contains('(dict/'));

    bloc.add(FeatureFlagsSnapshotChanged(_snapshot(false)));
    await tester.pump();

    expect(_markdownData(tester).single, choiceText);
  });

  testWidgets('текст вопроса проходит через тот же тумблер', (tester) async {
    final texts = <String>[];
    for (final highlight in [true, false]) {
      await tester.pumpWidget(
        wrap(
          FeatureFlagsBloc(_StubFlags(highlight: highlight)),
          Builder(
            builder: (context) =>
                Text(dictLinks(context, question.text.trim())),
          ),
        ),
      );
      texts.add(tester.widget<Text>(find.byType(Text)).data!);
    }

    expect(texts.first, contains('(dict/'));
    expect(texts.last, questionText);
  });
}
