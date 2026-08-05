import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
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

  test('конспект без категории не превращается в экран с ошибкой', () {
    // Так выглядит родитель диплинка `/konspekt/question/7921`: категории в
    // пути нет, показывать нечего. Redirect выкидывает такую страницу из
    // стека — вместо «Не удалось загрузить конспект» под вопросом.
    expect(_build('/konspekt'), isA<Redirect>());
    expect(_build('/konspekt?category=25'), isA<MaterialPage>());
  });
}
