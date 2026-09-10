import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/auth/presentation/auth_flow.dart';
import 'package:saobracaj/core/navigation.dart';

/// Поток входа поверх любого экрана: экраны тут заглушки с подписью, чтобы
/// проверять только навигацию — где лежит экран входа, куда возвращает
/// завершение потока и что делает системная кнопка «назад».
class _Screen extends StatelessWidget {
  const _Screen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text(label)),
  );
}

final _routes = RouteMap(
  routes: {
    '/': (_) => const MaterialPage(child: _Screen('главная')),
    '/quest': (_) => const MaterialPage(child: _Screen('вопрос')),
    '/quest/tariffs': (_) => const MaterialPage(child: _Screen('тарифы')),
    // Адреса потока для прямых ссылок — как в настоящей таблице маршрутов.
    '/login': (_) => const MaterialPage(child: _Screen('вход')),
    '/register': (_) => const MaterialPage(child: _Screen('регистрация')),
    '/resetPassword': (_) => const MaterialPage(child: _Screen('сброс')),
  },
);

late RoutemasterDelegate _delegate;

/// Приложение, собранное как настоящее: наблюдатель корневого навигатора и
/// диспетчер кнопки «назад» те же, что в `main.dart`.
Future<void> _pumpApp(WidgetTester tester) async {
  final rootRoutes = RootRoutesObserver();
  _delegate = RoutemasterDelegate(
    routesBuilder: (_) => _routes,
    observers: [rootRoutes],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routerDelegate: _delegate,
      routeInformationParser: const RoutemasterParser(),
      backButtonDispatcher: AppBackButtonDispatcher(rootRoutes),
    ),
  );
  await tester.pumpAndSettle();
}

String get _path => _delegate.currentConfiguration!.path;

BuildContext _contextOf(String label) => find.text(label).evaluate().single;

Future<void> _openTariffs(WidgetTester tester) async {
  _delegate.push('/quest');
  await tester.pumpAndSettle();
  _delegate.push('/quest/tariffs');
  await tester.pumpAndSettle();
  expect(find.text('тарифы'), findsOneWidget);
}

Future<void> _openLoginOver(WidgetTester tester, String label) async {
  unawaited(
    openAuthFlow(
      _contextOf(label),
      path: loginPath,
      screen: () => const _Screen('вход'),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('вход'), findsOneWidget);
}

void main() {
  testWidgets('вход ложится поверх витрины, а завершение возвращает на неё', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTariffs(tester);

    await _openLoginOver(tester, 'тарифы');
    // Адрес — по-прежнему витрины: стек под входом не тронут.
    expect(_path, '/quest/tariffs');

    await finishAuthFlow(_contextOf('вход'));
    await tester.pumpAndSettle();

    expect(find.text('вход'), findsNothing);
    expect(find.text('тарифы'), findsOneWidget);
    expect(_path, '/quest/tariffs');
  });

  testWidgets('регистрация и код встают на место входа, сброс — сверху, '
      'а завершение снимает весь поток разом', (tester) async {
    await _pumpApp(tester);
    await _openTariffs(tester);
    await _openLoginOver(tester, 'тарифы');

    authFlowReplace(
      _contextOf('вход'),
      path: registerPath,
      screen: () => const _Screen('регистрация'),
    );
    await tester.pumpAndSettle();
    expect(find.text('вход'), findsNothing);
    expect(find.text('регистрация'), findsOneWidget);

    unawaited(
      authFlowPush(
        _contextOf('регистрация'),
        path: resetPasswordPath,
        screen: () => const _Screen('сброс'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('сброс'), findsOneWidget);
    expect(_path, '/quest/tariffs');

    await finishAuthFlow(_contextOf('сброс'));
    await tester.pumpAndSettle();

    expect(find.text('сброс'), findsNothing);
    expect(find.text('регистрация'), findsNothing);
    expect(find.text('тарифы'), findsOneWidget);
    expect(_path, '/quest/tariffs');
  });

  testWidgets('вход поверх экрана без адреса возвращает на этот же экран', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTariffs(tester);
    // Экран, которого в таблице маршрутов нет, — запасная ветка pushScreen.
    unawaited(
      pushScreen(
        _contextOf('тарифы'),
        path: 'nowhere',
        screen: () => const _Screen('без адреса'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('без адреса'), findsOneWidget);

    await _openLoginOver(tester, 'без адреса');
    await finishAuthFlow(_contextOf('вход'));
    await tester.pumpAndSettle();

    expect(find.text('вход'), findsNothing);
    expect(find.text('без адреса'), findsOneWidget);
    expect(_path, '/quest/tariffs');
  });

  testWidgets('поток, открытый по адресу, идёт адресами и кончается вне их', (
    tester,
  ) async {
    await _pumpApp(tester);
    _delegate.push('/login');
    await tester.pumpAndSettle();
    expect(find.text('вход'), findsOneWidget);

    unawaited(
      authFlowPush(
        _contextOf('вход'),
        path: resetPasswordPath,
        screen: () => const _Screen('сброс'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_path, '/resetPassword');

    await finishAuthFlow(_contextOf('сброс'));
    await tester.pumpAndSettle();

    expect(find.text('сброс'), findsNothing);
    expect(find.text('вход'), findsNothing);
    expect(find.text('главная'), findsOneWidget);
    expect(_path, '/');
  });

  testWidgets('системная кнопка «назад» закрывает вход, а не экран под ним', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTariffs(tester);
    await _openLoginOver(tester, 'тарифы');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('вход'), findsNothing);
    expect(find.text('тарифы'), findsOneWidget);
    expect(_path, '/quest/tariffs');

    // Без императивного роута наверху «назад» — по-прежнему шаг routemaster'а.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('тарифы'), findsNothing);
    expect(find.text('вопрос'), findsOneWidget);
    expect(_path, '/quest');
  });
}
