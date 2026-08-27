import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/core/deep_links/deep_link_service.dart';
import 'package:saobracaj/main.dart' show AppRouteInformationParser;

void main() {
  group('deepLinkPathFor', () {
    test('a shared-list link becomes the shared route', () {
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/shared/ABCDEFGH')),
        '/shared/ABCDEFGH',
      );
      expect(
        deepLinkPathFor(Uri.parse('saobracaj://saobracaj.gleb.at/shared/ABCDEFGH')),
        '/shared/ABCDEFGH',
      );
    });

    test('an invite link becomes the invite route', () {
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/invite/ABC-DEF-GHI')),
        '/invite/ABC-DEF-GHI',
      );
      // The same address under the app's own scheme.
      expect(
        deepLinkPathFor(Uri.parse('saobracaj://saobracaj.gleb.at/invite/ABC-DEF-GHI')),
        '/invite/ABC-DEF-GHI',
      );
    });

    test('the query survives, so a link can point at a comment thread', () {
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/question/11?comments=1&thread=7')),
        '/question/11?comments=1&thread=7',
      );
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/konspekt?category=25&section=manevri')),
        '/konspekt?category=25&section=manevri',
      );
    });

    test('the scheme-only form keeps working (saobracaj://question/123)', () {
      expect(deepLinkPathFor(Uri.parse('saobracaj://question/123')), '/question/123');
    });

    test('the site root opens the app at home', () {
      expect(deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/')), '/');
      expect(deepLinkPathFor(Uri.parse('https://www.saobracaj.gleb.at')), '/');
    });

    test('хвостовой слэш не ломает маршрут', () {
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/question/10913/')),
        '/question/10913',
      );
    });

    test('links that are not ours are ignored', () {
      // Someone else's domain, however similar.
      expect(deepLinkPathFor(Uri.parse('https://saobracaj.example.com/invite/A')), isNull);
      expect(deepLinkPathFor(Uri.parse('https://evil.gleb.at/invite/A')), isNull);
      // The API host is not the app.
      expect(deepLinkPathFor(Uri.parse('https://api.saobracaj.gleb.at/graphql')), isNull);
      // A scheme we never registered.
      expect(deepLinkPathFor(Uri.parse('mailto:someone@example.com')), isNull);
    });

    test('a route that only exists as a child of a screen is not linkable', () {
      // '/quest' and '/start' need state the link cannot carry; opening them
      // cold would land on a broken screen.
      expect(deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/quest')), isNull);
      expect(deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/nonsense')), isNull);
    });

    test('страницы оплаты — не наши на мобильном, но наши в вебе', () {
      // Продажа живёт только в вебе (App Store 3.1.3(b)): в мобильном
      // приложении такую ссылку должен открыть браузер, поэтому все три
      // адреса денег для него «чужие» — во всех формах, какими они приходят.
      const money = [
        'https://saobracaj.gleb.at/tariffs',
        'https://saobracaj.gleb.at/subscription',
        'https://saobracaj.gleb.at/settings/subscription',
        'saobracaj://tariffs',
        'saobracaj://saobracaj.gleb.at/settings/subscription',
      ];
      for (final link in money) {
        expect(deepLinkPathFor(Uri.parse(link)), isNull, reason: link);
      }
      // В вебе это обычные экраны — ссылка внутри приложения открывает их же.
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/tariffs'), isWeb: true),
        '/tariffs',
      );
      expect(
        deepLinkPathFor(
          Uri.parse('https://saobracaj.gleb.at/settings/subscription'),
          isWeb: true,
        ),
        '/settings/subscription',
      );
      // Остальные разделы настроек мобильному по-прежнему доступны.
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/settings/profile')),
        '/settings/profile',
      );
    });

    test('a code with characters worth escaping is escaped once', () {
      final path = deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/lists/my%20list'));
      expect(path, '/lists/my%20list');
    });
  });

  group('AppRouteInformationParser', () {
    // Так системный источник (встроенная обработка диплинков движка) отдаёт
    // ссылку роутеру: полный URL со схемой. Раньше он целиком становился
    // «путём» и каждая живая ссылка открывала «страница не найдена».
    test('полный URL нормализуется в путь маршрута', () async {
      final parser = AppRouteInformationParser();
      final data = await parser.parseRouteInformation(
        RouteInformation(
          uri: Uri.parse('https://saobracaj.gleb.at/question/7923'),
        ),
      );
      expect(data.path, '/question/7923');
    });

    test('чужой URL уводит на главную, а не в «не найдено»', () async {
      final parser = AppRouteInformationParser();
      final data = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('https://example.com/whatever')),
      );
      expect(data.path, '/');
    });

    test('обычный путь проходит как есть', () async {
      final parser = AppRouteInformationParser();
      final data = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/question/7923?comments=1')),
      );
      expect(data.path, '/question/7923');
    });

    // Записи истории браузера переживают перезагрузку страницы, а нумерация
    // хронологической истории routemaster — нет: после F5 она начинается
    // заново. Поэтому каждая запись помечается сеансом, который её написал.
    test('запись своего сеанса разбирается вместе с состоянием', () async {
      final parser = AppRouteInformationParser();
      final own = parser.restoreRouteInformation(
        RouteData(
          '/lists/my-list',
          pathTemplate: '/lists/:id',
          pathParameters: const {'id': 'my-list'},
        ),
      );
      final data = await parser.parseRouteInformation(own);
      expect(data.pathTemplate, '/lists/:id');
      expect(data.pathParameters['id'], 'my-list');
    });

    test('запись чужого сеанса открывается по адресу, а не по индексу', () async {
      // Так выглядит запись, оставленная прошлым запуском приложения: индекс
      // в ней указывает на несуществующую запись хронологической истории, и
      // «назад» либо ничего не делал, либо уезжал на посторонний экран.
      final stale = RouteInformation(
        uri: Uri.parse('/lists/my-list'),
        state: const {
          'isReplacement': false,
          'internalPath': '/lists/my-list',
          'requestSource': 'RequestSource.internal',
          'pathTemplate': '/lists/:id',
          'pathParameters': {'id': 'my-list'},
          'historyIndex': 7,
          'appSession': 'какой-то прошлый запуск',
        },
      );
      final data = await AppRouteInformationParser().parseRouteInformation(stale);
      expect(data.path, '/lists/my-list');
      // Состояние прошлого сеанса отброшено: маршрут разобран из адреса.
      expect(data.pathTemplate, '/lists/my-list');
    });
  });

  group('DeepLinkService', () {
    test('a link that arrives before the app is built is kept, then consumed', () async {
      final service = DeepLinkService();
      addTearDown(service.dispose);

      service.handleLink(Uri.parse('https://saobracaj.gleb.at/invite/ABC-DEF-GHI'));

      expect(service.takePending(), '/invite/ABC-DEF-GHI');
      // Only once — a rebuild must not reopen the invitation.
      expect(service.takePending(), isNull);
    });

    test('a link that arrives while the app is running goes to the listener', () async {
      final service = DeepLinkService();
      addTearDown(service.dispose);
      final opened = <String>[];
      service.paths.listen(opened.add);
      // Give the broadcast stream a turn to register the listener.
      await Future<void>.delayed(Duration.zero);

      service.handleLink(Uri.parse('https://saobracaj.gleb.at/invite/ABC-DEF-GHI'));
      service.handleLink(Uri.parse('https://example.com/invite/OTHER'));
      await Future<void>.delayed(Duration.zero);

      expect(opened, ['/invite/ABC-DEF-GHI']);
      expect(service.takePending(), isNull);
    });
  });
}
