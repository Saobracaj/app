import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/test/quest/quest.dart';

/// Задача 1203867458890041: открыл диплинк на вопрос, ушёл в мессенджер, нажал
/// ссылку на другой вопрос — а на экране по-прежнему первый.
///
/// Routemaster для второй ссылки строит новую `MaterialPage`, но Navigator
/// считает две страницы одного типа без ключа одним и тем же роутом и лишь
/// подменяет виджет под живым элементом: `BlocProvider(create:)` внутри
/// [Quest] не пересоздаётся, и блок первого вопроса продолжает жить. Поэтому
/// страницы с параметрами ключуются адресом ([keyedPage]) — и второй вопрос
/// получает свой экран.
///
/// Таблица маршрутов здесь своя: боевая «/» тянет за собой все блоки главной,
/// а проверяется только страница вопроса ([questCommentsPage] — боевой билдер).
RouteMap _routes() => RouteMap(
  routes: {
    '/': (_) => const MaterialPage(child: Scaffold(body: Text('дом'))),
    '/question/:id': questCommentsPage,
  },
);

/// Экран вопроса без данных крутит спиннер, так что `pumpAndSettle` не
/// дождётся покоя — ждём столько, сколько идёт переход между страницами.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('второй диплинк на другой вопрос открывает другой вопрос', (
    tester,
  ) async {
    final delegate = RoutemasterDelegate(routesBuilder: (_) => _routes());
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      BlocProvider(
        // Без Load(): данных нет, экран вопроса показывает загрузку — для
        // проверки пересоздания экрана этого достаточно.
        create: (_) => AllQuestionsBloc(),
        child: MaterialApp.router(
          routerDelegate: delegate,
          routeInformationParser: const RoutemasterParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Первая ссылка — как её пушит DeepLinkService через _openDeepLink.
    delegate.push('/question/7921');
    await _settle(tester);
    final first = tester.element(find.byType(Quest));
    expect(tester.widget<Quest>(find.byType(Quest)).questions, [7921]);

    // Вторая ссылка поверх открытого вопроса.
    delegate.push('/question/7922');
    await _settle(tester);
    expect(find.byType(Quest), findsOneWidget);
    expect(tester.widget<Quest>(find.byType(Quest)).questions, [7922]);
    // Именно новый экран, а не тот же элемент с подменённым виджетом.
    expect(tester.element(find.byType(Quest)), isNot(same(first)));
    expect(delegate.currentConfiguration?.path, '/question/7922');

    // Та же ссылка второй раз ничего не пересоздаёт: экран остаётся тем же.
    final second = tester.element(find.byType(Quest));
    delegate.push('/question/7922');
    await _settle(tester);
    expect(tester.element(find.byType(Quest)), same(second));
  });
}
