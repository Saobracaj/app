import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/question_lists/domain/list_style.dart';
import 'package:saobracaj/question_lists/models/question_list.dart';
import 'package:saobracaj/question_lists/presentation/question_lists_section.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:saobracaj/theme/quiz_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Плитка списка вопросов по карточке дизайн-системы «Списки вопросов»:
/// иконка-тайл, название, счётчик. Иконка и подложка — всегда пара
/// «цвет / on-цвет», у пользовательских списков on-цвет считается по яркости.

/// Оборачивает [builder] в локализацию с настоящими переводами и тему
/// приложения нужной схемы.
Widget _app({
  required Brightness brightness,
  required Widget Function(BuildContext) builder,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: brightness,
  );
  return EasyLocalization(
    useOnlyLangCode: true,
    ignorePluralRules: false,
    supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
    fallbackLocale: const Locale('ru'),
    startLocale: const Locale('ru'),
    path: 'assets/translations',
    assetLoader: const CodegenLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: buildAppTheme(scheme),
        home: Scaffold(body: Center(child: Builder(builder: builder))),
      ),
    ),
  );
}

/// Иконка внутри плитки и цвет её подложки.
({Icon icon, Color background}) _tile(WidgetTester tester) {
  final icon = tester.widget<Icon>(
    find.descendant(
      of: find.byType(QuestionListAvatar),
      matching: find.byType(Icon),
    ),
  );
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(QuestionListAvatar),
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration as BoxDecoration;
  return (icon: icon, background: decoration.color!);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('onListColor', () {
    test('на тёмном цвете — белый, на светлом — чёрный', () {
      // Жёлтый из палитры списков: белая иконка на нём не читается.
      expect(onListColor(const Color(0xFFFDD835)), Colors.black87);
      expect(onListColor(const Color(0xFF3949AB)), Colors.white);
    });
  });

  group('Плитка списка', () {
    testWidgets('автосписок ошибок берёт пару wrong/onWrong из токенов '
        'викторины', (tester) async {
      late ThemeData theme;
      await tester.pumpWidget(
        _app(
          brightness: Brightness.dark,
          builder: (context) {
            theme = Theme.of(context);
            return const QuestionListChip(
              list: QuestionList(
                id: kRecentMistakesListId,
                isAuto: true,
                questionIds: [1, 2, 3],
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final tile = _tile(tester);
      expect(tile.background, theme.quiz.wrong);
      expect(tile.icon.color, theme.quiz.onWrong);
      // Белым поверх primary тёмной схемы иконка не рисуется — именно этот
      // случай не проходил по контрасту.
      expect(tile.icon.color, isNot(Colors.white));
    });

    testWidgets('у пользовательского списка иконка в on-цвете к выбранному '
        'цвету', (tester) async {
      const yellow = Color(0xFFFDD835);
      await tester.pumpWidget(
        _app(
          brightness: Brightness.light,
          builder: (_) => const QuestionListChip(
            list: QuestionList(
              id: 'a1',
              name: 'Знаки',
              color: 0xFFFDD835,
              questionIds: [1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = _tile(tester);
      expect(tile.background, yellow);
      expect(tile.icon.color, onListColor(yellow));
    });

    testWidgets('показывает название и счётчик вопросов во множественном '
        'числе', (tester) async {
      await tester.pumpWidget(
        _app(
          brightness: Brightness.light,
          builder: (_) => QuestionListChip(
            list: QuestionList(
              id: 'a1',
              name: 'Знаки',
              color: 0xFF8E24AA,
              questionIds: List.generate(12, (i) => i),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Знаки'), findsOneWidget);
      expect(find.text('12 вопросов'), findsOneWidget);
    });

    testWidgets('в ленте плитка шириной 150 и иконка-тайл сверху над названием', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          brightness: Brightness.light,
          builder: (_) => const QuestionListChip(
            list: QuestionList(
              id: 'a1',
              name: 'Знаки',
              color: 0xFF8E24AA,
              questionIds: [1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(QuestionListChip)).width, 150);
      final avatar = tester.getRect(find.byType(QuestionListAvatar));
      final title = tester.getRect(find.text('Знаки'));
      expect(avatar.bottom, lessThanOrEqualTo(title.top));
      expect(avatar.left, title.left);
      // Тайл — скруглённый квадрат 30×30, а не круг.
      expect(avatar.size, const Size(30, 30));
    });
  });
}
