import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/core/deep_links/deep_link_service.dart';

void main() {
  group('deepLinkPathFor', () {
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

    test('a code with characters worth escaping is escaped once', () {
      final path = deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/lists/my%20list'));
      expect(path, '/lists/my%20list');
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
