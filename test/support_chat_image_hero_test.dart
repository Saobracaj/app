import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/generated/codegen_loader.g.dart';
import 'package:saobracaj/support_chat/data/support_chat_repository.dart';
import 'package:saobracaj/support_chat/models/support_chat.dart';
import 'package:saobracaj/support_chat/presentation/support_attachment_views.dart';
import 'package:saobracaj/support_chat/state_management/support_image_bloc.dart';
import 'package:saobracaj/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Открытие картинки из чата на полный экран: снимок в пузыре и полный экран —
/// один и тот же hero, и он летит с сохранением кадрирования.

/// Картинка 40×20 (пропорции 2:1) — по ней проверяем, что полный экран
/// приземляется ровно на прямоугольник фотографии, а не на весь экран.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAJElEQVR42mM4YWMz'
  'IIhh1OJRi0ctHrV41OJRi0ctHrV45FgMAGQL6C7Nm8rTAAAAAElFTkSuQmCC',
);

const _url = 'https://cdn.test/photo.png';

/// Сеть для `Image.network`: отдаёт [_png] на любой запрос. Подменяется через
/// [HttpOverrides], а не через `debugNetworkImageHttpClientProvider` — тест не
/// имеет права оставить после себя изменённый отладочный флаг painting.
class _FakeOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_png).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ссылка на вложение в тесте не протухает, так что перевыпуск не спрашивают.
class _StubChatRepository implements SupportChatRepository {
  @override
  Future<String> attachmentUrl(String attachmentId) async => _url;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _attachment = SupportAttachment(
  id: 'a1',
  kind: SupportAttachmentKind.image,
  fileName: 'снимок.png',
  contentType: 'image/png',
  url: _url,
  createdAt: DateTime(2026, 8, 9),
);

Widget _host() => EasyLocalization(
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
      theme: buildAppTheme(ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: Scaffold(
        body: Center(
          child: SupportAttachmentView(
            attachment: _attachment,
            onSurface: Colors.black,
          ),
        ),
      ),
    ),
  ),
);

/// Показать пузырь и дождаться, пока картинка декодируется: загрузка идёт по
/// настоящим асинхронным каналам, которые в тесте живут только внутри
/// [WidgetTester.runAsync].
Future<void> _pumpBubble(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  // Переводы грузятся асинхронно — до этого дерева приложения ещё нет.
  await tester.pump();
  await tester.pump();
  await tester.runAsync(
    () => precacheImage(
      NetworkImage(_url),
      tester.element(find.byType(MaterialApp)),
    ),
  );
  // Дальше картинка отдаётся из кэша сразу, без бесконечного индикатора
  // загрузки — иначе pumpAndSettle не дождался бы покоя.
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    HttpOverrides.global = _FakeOverrides();
  });

  tearDownAll(() => HttpOverrides.global = null);

  setUp(() {
    getIt.registerFactoryParam<SupportImageBloc, SupportAttachment, void>(
      (attachment, _) => SupportImageBloc(_StubChatRepository(), attachment),
    );
  });

  tearDown(() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    await getIt.reset();
  });

  testWidgets('снимок в пузыре и полный экран — один hero', (tester) async {
    await _pumpBubble(tester);

    final thumbnail = find.descendant(
      of: find.byType(SupportAttachmentView),
      matching: find.byType(Hero),
    );
    expect(
      tester.widget<Hero>(thumbnail).tag,
      supportImageHeroTag(_attachment),
    );

    await tester.tap(thumbnail);
    await tester.pumpAndSettle();

    // Открылся полный экран — и его картинка помечена тем же тегом.
    expect(find.text('снимок.png'), findsOneWidget);
    final full = tester.widget<Hero>(find.byType(Hero));
    expect(full.tag, supportImageHeroTag(_attachment));
  });

  testWidgets('полный экран приземляется на пропорции самой фотографии', (
    tester,
  ) async {
    await _pumpBubble(tester);
    await tester.tap(find.byType(Hero));
    await tester.pumpAndSettle();

    // 40×20 — значит бокс вдвое шире своей высоты, а не во весь экран:
    // hero заканчивает полёт ровно там, где будет лежать фотография.
    final box = tester.getRect(
      find.descendant(
        of: find.byType(Hero),
        matching: find.byType(AspectRatio),
      ),
    );
    expect(box.width / box.height, closeTo(2, 0.01));
  });

  testWidgets('в полёте картинка растёт и распрямляет углы', (tester) async {
    await _pumpBubble(tester);
    final start = tester.getRect(find.byType(Hero));

    await tester.tap(find.byType(Hero));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Летит именно снимок: единственная картинка в дереве — в оверлее, между
    // размером пузыря и полным экраном.
    final flying = tester.getRect(find.byType(Image));
    expect(flying.width, greaterThan(start.width));
    expect(flying.width, lessThan(800));

    // И скругление в полёте уже не такое, как у пузыря, но ещё не нулевое.
    final clip = tester.widget<ClipRRect>(
      find
          .ancestor(of: find.byType(Image), matching: find.byType(ClipRRect))
          .first,
    );
    final radius = (clip.borderRadius as BorderRadius).topLeft.x;
    expect(radius, greaterThan(0));
    expect(radius, lessThan(kSupportImageRadius));

    await tester.pumpAndSettle();
  });
}
