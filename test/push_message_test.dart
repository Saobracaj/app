import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/deep_links/deep_link_path.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/notifications/data/push_message.dart';
import 'package:saobracaj/notifications/data/push_message_service.dart';
import 'package:saobracaj/notifications/presentation/push_message_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push-уведомления: что приложение вычитывает из сообщения FCM, куда ведёт
/// ссылка из него и как выглядит снекбар для уведомления, пришедшего в
/// foreground.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('PushMessage.fromRemote', () {
    test('берёт заголовок и текст из блока notification, ссылку — из data', () {
      final push = PushMessage.fromRemote(
        const RemoteMessage(
          notification: RemoteNotification(title: 'Ответ', body: 'Вам ответили'),
          data: {'link': 'saobracaj://question/11?comments=1&thread=7'},
        ),
      );
      expect(push, isNotNull);
      expect(push!.title, 'Ответ');
      expect(push.body, 'Вам ответили');
      expect(
        push.link,
        Uri.parse('saobracaj://question/11?comments=1&thread=7'),
      );
    });

    test('заголовок и текст из data — запасной вариант для data-сообщений', () {
      final push = PushMessage.fromRemote(
        const RemoteMessage(data: {'title': ' T ', 'body': 'B', 'link': ''}),
      );
      expect(push, const PushMessage(title: 'T', body: 'B'));
    });

    test('сообщение без текста и без ссылки — не уведомление', () {
      expect(PushMessage.fromRemote(const RemoteMessage(data: {})), isNull);
      expect(
        PushMessage.fromRemote(const RemoteMessage(data: {'link': '   '})),
        isNull,
      );
    });

    test('голый путь читается как адрес на своём домене', () {
      expect(
        PushMessage.parseLink('/settings'),
        Uri.parse('https://saobracaj.gleb.at/settings'),
      );
      expect(
        PushMessage.parseLink('/question/11?comments=1&thread=7'),
        Uri.parse('https://saobracaj.gleb.at/question/11?comments=1&thread=7'),
      );
    });

    test('чужая ссылка сохраняется как есть — её откроет браузер', () {
      final uri = PushMessage.parseLink('https://example.com/news?id=1');
      expect(uri, Uri.parse('https://example.com/news?id=1'));
      expect(deepLinkPathFor(uri!), isNull);
    });

    test('мусор вместо ссылки не роняет разбор', () {
      expect(PushMessage.parseLink('not a link'), isNull);
      expect(PushMessage.parseLink(42), isNull);
      expect(PushMessage.parseLink(null), isNull);
    });
  });

  group('ссылки из уведомлений открываются внутри приложения', () {
    // Ровно те формы, которые перечислены в задаче и которые шлёт бэкенд.
    test('https://saobracaj.gleb.at/…', () {
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/question/123')),
        '/question/123',
      );
    });

    test('saobracaj://saobracaj.gleb.at/…', () {
      expect(
        deepLinkPathFor(
          Uri.parse('saobracaj://saobracaj.gleb.at/question/123?comments=1'),
        ),
        '/question/123?comments=1',
      );
    });

    test('saobracaj://support и /settings — то, что шлёт бэкенд сейчас', () {
      expect(deepLinkPathFor(Uri.parse('saobracaj://support')), '/support');
      expect(
        deepLinkPathFor(PushMessage.parseLink('/settings')!),
        '/settings',
      );
      // Страница подписки существует только в вебе: там пуш открывает её
      // внутри, а в мобильном приложении та же ссылка уходит в браузер
      // (deepLinkPathFor возвращает null → launchUrl).
      expect(
        deepLinkPathFor(
          Uri.parse('https://saobracaj.gleb.at/subscription'),
          isWeb: true,
        ),
        '/subscription',
      );
      expect(
        deepLinkPathFor(Uri.parse('https://saobracaj.gleb.at/subscription')),
        isNull,
      );
    });
  });

  group('PushMessageService', () {
    test('нажатое уведомление до постройки дерева хранится до takePendingOpen',
        () async {
      final service = PushMessageService();
      service.handleOpened(
        const RemoteMessage(
          notification: RemoteNotification(title: 'T'),
          data: {'link': 'saobracaj://support'},
        ),
      );
      final pending = service.takePendingOpen();
      expect(pending?.link, Uri.parse('saobracaj://support'));
      // Забирается один раз.
      expect(service.takePendingOpen(), isNull);
      await service.dispose();
    });

    test('при живом слушателе нажатое уведомление уходит в поток opened',
        () async {
      final service = PushMessageService();
      final received = <PushMessage>[];
      final sub = service.opened.listen(received.add);
      service.handleOpened(
        const RemoteMessage(data: {'link': '/settings'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.single.link, Uri.parse('https://saobracaj.gleb.at/settings'));
      expect(service.takePendingOpen(), isNull);
      await sub.cancel();
      await service.dispose();
    });

    test('нажатое уведомление без ссылки открывать нечего — игнорируется',
        () async {
      final service = PushMessageService();
      service.handleOpened(
        const RemoteMessage(notification: RemoteNotification(title: 'T')),
      );
      expect(service.takePendingOpen(), isNull);
      await service.dispose();
    });

    test('foreground-уведомление уходит в поток foreground целиком', () async {
      final service = PushMessageService();
      final received = <PushMessage>[];
      final sub = service.foreground.listen(received.add);
      service.handleForeground(
        const RemoteMessage(
          notification: RemoteNotification(title: 'T', body: 'B'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, [const PushMessage(title: 'T', body: 'B')]);
      await sub.cancel();
      await service.dispose();
    });
  });

  group('снекбар foreground-уведомления', () {
    setUpAll(() async {
      await EasyLocalization.ensureInitialized();
    });

    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    Widget app() {
      return EasyLocalization(
        useOnlyLangCode: true,
        supportedLocales: const [Locale('sr'), Locale('ru'), Locale('en')],
        fallbackLocale: const Locale('ru'),
        startLocale: const Locale('ru'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const CodegenLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            scaffoldMessengerKey: messengerKey,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
    }

    testWidgets('показывает заголовок, текст и кнопку «Перейти»', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      var opened = 0;
      messengerKey.currentState!.showSnackBar(
        buildPushMessageSnackBar(
          PushMessage(
            title: 'Новый ответ',
            body: 'Вам ответили в обсуждении',
            link: Uri.parse('saobracaj://question/11'),
          ),
          onOpen: () => opened++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Новый ответ'), findsOneWidget);
      expect(find.text('Вам ответили в обсуждении'), findsOneWidget);
      expect(find.text('Перейти'), findsOneWidget);

      await tester.tap(find.text('Перейти'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('без ссылки кнопки «Перейти» нет', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      messengerKey.currentState!.showSnackBar(
        buildPushMessageSnackBar(
          const PushMessage(title: 'Только текст', body: 'Без перехода'),
          onOpen: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Только текст'), findsOneWidget);
      expect(find.text('Перейти'), findsNothing);
    });
  });
}
