import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/support_chat/presentation/linked_text.dart';
import 'package:saobracaj/util/nav_to_url.dart';

/// Ссылка на saobracaj.gleb.at ведёт на экран, который у приложения уже есть,
/// — уводить за ней в браузер незачем. Проверяем на настоящем роутере: тестовая
/// таблица маршрутов повторяет боевые пути, потому что «открыть поверх текущего
/// экрана» у routemaster существует только как зарегистрированный путь.

/// Куда ушёл роутер по последнему нажатию.
final _visited = <String>[];

Widget _screen(String label) => Scaffold(body: Text(label));

RouteMap _routes(WidgetBuilder home) => RouteMap(
  onUnknownRoute: (path) => MaterialPage(child: _screen('404 $path')),
  routes: {
    '/': (_) => MaterialPage(child: Builder(builder: home)),
    '/question/:id': (data) =>
        MaterialPage(child: _screen('вопрос ${data.pathParameters['id']}')),
    '/konspekt': (data) => MaterialPage(
      child: _screen('конспект ${data.queryParameters['category']}'),
    ),
  },
);

/// Приложение с одной кнопкой, которая открывает [uri] через [onTap].
Widget _app(Uri uri, void Function(BuildContext, Uri) onTap) {
  final delegate = RoutemasterDelegate(routesBuilder: (_) => _routes(
    (context) => Scaffold(
      body: TextButton(
        onPressed: () => onTap(context, uri),
        child: const Text('ссылка'),
      ),
    ),
  ));
  return MaterialApp.router(
    routerDelegate: delegate,
    routeInformationParser: const RoutemasterParser(),
  );
}

Future<void> _tapLink(
  WidgetTester tester,
  String link, {
  void Function(BuildContext, Uri)? onTap,
}) async {
  await tester.pumpWidget(
    _app(Uri.parse(link), onTap ?? (context, uri) {
      _visited.add(openAppUri(context, uri) ? 'in-app' : 'browser');
    }),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('ссылка'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_visited.clear);

  testWidgets('ссылка на вопрос открывает экран вопроса', (tester) async {
    await _tapLink(tester, 'https://saobracaj.gleb.at/question/7923');

    expect(_visited, ['in-app']);
    expect(find.text('вопрос 7923'), findsOneWidget);
  });

  testWidgets('параметры адреса доезжают до экрана', (tester) async {
    await _tapLink(
      tester,
      'https://saobracaj.gleb.at/konspekt?category=25&section=manevri',
    );

    expect(find.text('конспект 25'), findsOneWidget);
  });

  testWidgets('чужая ссылка остаётся браузеру', (tester) async {
    await _tapLink(tester, 'https://example.com/a');

    expect(_visited, ['browser']);
    expect(find.text('ссылка'), findsOneWidget);
  });

  testWidgets('свой адрес без известного экрана тоже уходит в браузер', (
    tester,
  ) async {
    await _tapLink(tester, 'https://saobracaj.gleb.at/blog/kako-voziti');

    expect(_visited, ['browser']);
  });

  testWidgets('ссылка из чата открывается в приложении без диалога', (
    tester,
  ) async {
    await _tapLink(
      tester,
      'https://saobracaj.gleb.at/question/8084',
      onTap: openMessageLink,
    );

    expect(find.text('вопрос 8084'), findsOneWidget);
    // Диалога «уходите на внешний сайт» для своей ссылки быть не должно.
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('чужая ссылка из чата спрашивает подтверждение', (tester) async {
    await _tapLink(tester, 'https://example.com/a', onTap: openMessageLink);

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
