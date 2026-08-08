import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/core/presentation/not_found_page.dart';
import 'package:saobracaj/routes.dart';

/// Экраны, которые вопрос умеет открывать поверх себя. Routemaster строит стек
/// из URL, поэтому «поверх вопроса» должно существовать как путь: иначе
/// относительный push уводит на «страница не найдена», а абсолютный — сносит
/// весь стек под собой (так «назад» из конспекта уезжал на главную).
const _questionPaths = [
  '/quest',
  '/quest/q',
  '/statistics/q',
  '/lists/my-list/q',
  '/questPractice/q',
  '/question/7921',
  '/konspekt/question/7921',
  '/groups/g1/feed/q',
];

/// Ссылки, которые приложению отдаёт система (или адресная строка на вебе).
/// Каждая обязана доехать до реального экрана: «Page wasn't found» на живой
/// ссылке — это то, с чего начиналась задача 1217292094173343.
const _externalLinks = [
  'https://saobracaj.gleb.at/question/10913',
  'https://saobracaj.gleb.at/question/10913/',
  'https://saobracaj.gleb.at/question/10913?comments=1',
  'https://saobracaj.gleb.at/invite/ABC-DEF-GHI',
  'https://saobracaj.gleb.at/groups/g1/feed',
  'https://saobracaj.gleb.at/konspekt?category=25',
  'https://saobracaj.gleb.at/zakon',
  'https://saobracaj.gleb.at/lists/my-list',
  'https://saobracaj.gleb.at/statistics',
  'https://saobracaj.gleb.at/about',
  'saobracaj://question/10913',
  'saobracaj://support/threads/t1',
];

RouteSettings? _build(String path) {
  final result = routes.get(path);
  if (result == null) return null;
  return result.builder(
    RouteData(path, pathTemplate: result.pathTemplate, pathParameters: result.pathParameters),
  );
}

void main() {
  test('каждый экран вопроса умеет открыть поверх себя закон и конспект', () {
    for (final host in _questionPaths) {
      expect(routes.get('$host/zakon'), isNotNull, reason: '$host/zakon');
      expect(routes.get('$host/konspekt'), isNotNull, reason: '$host/konspekt');
      expect(
        routes.get('$host/konspekt/zakon'),
        isNotNull,
        reason: '$host/konspekt/zakon',
      );
      expect(
        routes.get('$host/commentEdit'),
        isNotNull,
        reason: '$host/commentEdit',
      );
    }
  });

  test('конспект, открытый из вопроса, лежит поверх вопроса', () {
    // Стек строится из пути, поэтому под конспектом остаётся сам вопрос —
    // «назад» возвращает к нему, а не на главную.
    final stack = routes.getAll('/quest/konspekt')!.map((r) => r.pathTemplate);
    expect(stack, ['/', '/quest', '/quest/konspekt']);
  });

  test('экран вопросов без параметра q не роняет первый кадр', () {
    // Так выглядит набранный руками URL /quest (или /start) без q=1,2,3:
    // раньше `queryParameters['q']!` кидал исключение прямо в билдере роута,
    // и вся страница умирала в серый экран. Теперь — редирект на главную.
    expect(_build('/quest'), isA<Redirect>());
    expect(_build('/quest?q=abc'), isA<Redirect>());
    expect(_build('/quest?q=8084'), isA<MaterialPage>());
    expect(_build('/start'), isA<Redirect>());
    expect(_build('/start?q=8084'), isA<MaterialPage>());
  });

  test('диплинк /question/{id} строится без загруженных вопросов', () {
    // https://saobracaj.gleb.at/question/8084 — билдер роута не должен
    // требовать ничего, кроме пути: данные подтянет сам экран.
    expect(_build('/question/8084'), isA<MaterialPage>());
  });

  test('каждый диплинк ведёт на существующий маршрут', () {
    for (final link in _externalLinks) {
      final path = deepLinkPathFor(Uri.parse(link));
      expect(path, isNotNull, reason: 'ссылка не распознана: $link');
      expect(routes.get(path!), isNotNull, reason: 'нет маршрута для $path');
    }
  });

  test('неизвестный адрес показывает экран «страница не найдена»', () {
    // Раньше отсюда нельзя было выбраться, не перезапустив приложение.
    expect(routes.get('/такого/адреса/нет'), isNull);
    final page = routes.onUnknownRoute('/такого/адреса/нет');
    expect(page, isA<MaterialPage>());
    expect((page as MaterialPage).child, isA<NotFoundPage>());
  });

  test('конспект без категории не превращается в экран с ошибкой', () {
    // Так выглядит родитель диплинка `/konspekt/question/7921`: категории в
    // пути нет, показывать нечего. Redirect выкидывает такую страницу из
    // стека — вместо «Не удалось загрузить конспект» под вопросом.
    expect(_build('/konspekt'), isA<Redirect>());
    expect(_build('/konspekt?category=25'), isA<MaterialPage>());
  });
}
