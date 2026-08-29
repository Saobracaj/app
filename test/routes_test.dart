import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/core/presentation/not_found_page.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/test/quest/quest.dart';
import 'package:saobracaj/test/start_test.dart';

/// Экраны, которые вопрос умеет открывать поверх себя. Routemaster строит стек
/// из URL, поэтому «поверх вопроса» должно существовать как путь: иначе
/// относительный push уводит на «страница не найдена», а абсолютный — сносит
/// весь стек под собой (так «назад» из конспекта уезжал на главную).
const _questionPaths = [
  '/quest',
  '/quest/q',
  '/statistics/q',
  '/lists/my-list/q',
  '/shared/ABCDEFGH/q',
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
  'https://saobracaj.gleb.at/shared/ABCDEFGH',
  'https://saobracaj.gleb.at/groups/g1/feed',
  'https://saobracaj.gleb.at/konspekt?category=25',
  'https://saobracaj.gleb.at/zakon',
  'https://saobracaj.gleb.at/pravilnik',
  'https://saobracaj.gleb.at/pravilnik?chapter=II&chlan=13&paragraph=5',
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

  test('блок «null» в адресе прогона не считается блоком', () {
    // Прогон ошибок / списка идёт без блока, но старые сборки подставляли в
    // адрес `subcategory=null` — маршрут принимал строку «null» за id блока,
    // и результат уходил в статистику и в ленту группы как block “null”. Такие
    // адреса ещё живут в истории браузера, поэтому маршрут их терпит.
    Quest quest(String path) => (_build(path) as MaterialPage).child as Quest;
    StartTest start(String path) =>
        (_build(path) as MaterialPage).child as StartTest;
    expect(quest('/quest?q=8084&subcategory=null').subcategory, isNull);
    expect(quest('/quest?q=8084&subcategory=').subcategory, isNull);
    expect(quest('/quest?q=8084').subcategory, isNull);
    expect(quest('/quest?q=8084&subcategory=91').subcategory, '91');
    expect(start('/start?q=8084&subcategory=null').subcategory, isNull);
    expect(start('/start?q=8084&subcategory=91').subcategory, '91');
  });

  test('диплинк /question/{id} строится без загруженных вопросов', () {
    // https://saobracaj.gleb.at/question/8084 — билдер роута не должен
    // требовать ничего, кроме пути: данные подтянет сам экран.
    expect(_build('/question/8084'), isA<MaterialPage>());
  });

  test('группа: адрес без /feed редиректит в ленту, «назад» из неё — домой', () {
    // Redirect-родитель выпадает из стека, поэтому под лентой не остаётся
    // промежуточного экрана группы (раньше «назад» уводил на экран с QR).
    expect(_build('/groups/g1'), isA<Redirect>());
    final stack = routes
        .getAll('/groups/g1/feed/members')!
        .map((r) => r.pathTemplate);
    expect(stack, [
      '/',
      '/groups/:id',
      '/groups/:id/feed',
      '/groups/:id/feed/members',
    ]);
  });

  test('экран группы — две вкладки: чат и события', () {
    // Вкладки — настоящие адреса (TabPage), поэтому ссылка на разговор
    // открывает его вкладкой внутри группы, а не отдельным экраном поверх неё.
    // Чат идёт первым: группа открывается на разговоре.
    final page = _build('/groups/g1/feed');
    expect(page, isA<TabPage>());
    expect((page! as TabPage).paths, ['chat', 'events']);
    expect(_build('/groups/g1/feed/events'), isA<MaterialPage>());
    expect(_build('/groups/g1/feed/chat'), isA<MaterialPage>());
    // Вопросы события и управление группой остаются НАД экраном группы: внутри
    // вкладки они рисовались бы под её же шапкой.
    for (final path in const ['q', 'members', 'invite']) {
      final stack = routes
          .getAll('/groups/g1/feed/$path')!
          .map((r) => r.pathTemplate);
      expect(stack.last, '/groups/:id/feed/$path');
      expect(stack, contains('/groups/:id/feed'));
    }
  });

  test('участники и приглашение группы — отдельные маршруты под лентой', () {
    expect(routes.get('/groups/g1/feed/members'), isNotNull);
    expect(routes.get('/groups/g1/feed/invite'), isNotNull);
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

  test('переключение вкладок попадает в историю браузера', () {
    // По умолчанию (`TabBackBehavior.none`) routemaster только заменяет адрес
    // при переключении вкладки: истории не остаётся, и кнопка «назад» в
    // браузере уносила пользователя с сайта вместо возврата на предыдущую
    // вкладку — а вкладки и есть основная навигация приложения.
    final page = _build('/');
    expect(page, isA<IndexedPage>());
    expect((page as IndexedPage).backBehavior, TabBackBehavior.history);
  });

  test('конспект без категории не превращается в экран с ошибкой', () {
    // Так выглядит родитель диплинка `/konspekt/question/7921`: категории в
    // пути нет, показывать нечего. Redirect выкидывает такую страницу из
    // стека — вместо «Не удалось загрузить конспект» под вопросом.
    expect(_build('/konspekt'), isA<Redirect>());
    expect(_build('/konspekt?category=25'), isA<MaterialPage>());
  });
}
