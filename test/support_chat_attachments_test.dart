import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:saobracaj/support_chat/data/chat_image_cache.dart';
import 'package:saobracaj/support_chat/data/photo_compressor.dart';
import 'package:saobracaj/support_chat/presentation/shared_list_chip.dart';

/// Вложения чата: кэш картинок по вложению (а не по ссылке), пережатие
/// фотографий в JPEG и разбор ссылок на расшаренные списки.
///
/// Жесты просмотрщика (смахивание, листание, стрелки) сюда не входят — они
/// проверяются вручную, см. сабтаску тестирования.

/// PNG 40×20 — минимальная настоящая картинка, чтобы декодер был доволен.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAJElEQVR42mM4YWMz'
  'IIhh1OJRi0ctHrV41OJRi0ctHrV45FgMAGQL6C7Nm8rTAAAAAElFTkSuQmCC',
);

void main() {
  group('кэш картинок', () {
    late List<String> requested;

    setUp(() {
      requested = [];
      ChatImageStore.instance.resetInFlight();
      ChatImageStore.instance.client = MockClient((request) async {
        requested.add(request.url.toString());
        return http.Response.bytes(_png, 200);
      });
    });

    tearDown(() {
      ChatImageStore.instance.resetInFlight();
      imageCache.clear();
      imageCache.clearLiveImages();
    });

    testWidgets('две подписанные ссылки на одно вложение — одна загрузка', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(MaterialApp));

      // Ссылки живут пятнадцать минут, и каждое перечитывание переписки выдаёт
      // новые. Кэш ключуется вложением, поэтому вторая ссылка ничего не качает.
      await tester.runAsync(() async {
        await precacheImage(
          const CachedChatImage(
            attachmentId: 'a1',
            url: 'https://cdn.test/a1.png?sig=first',
          ),
          context,
        );
        await precacheImage(
          const CachedChatImage(
            attachmentId: 'a1',
            url: 'https://cdn.test/a1.png?sig=second',
          ),
          context,
        );
      });

      expect(requested, ['https://cdn.test/a1.png?sig=first']);
    });

    testWidgets('разные вложения качаются каждое своё', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(MaterialApp));
      await tester.runAsync(() async {
        for (final id in ['a1', 'a2']) {
          await precacheImage(
            CachedChatImage(attachmentId: id, url: 'https://cdn.test/$id.png'),
            context,
          );
        }
      });
      expect(requested, [
        'https://cdn.test/a1.png',
        'https://cdn.test/a2.png',
      ]);
    });
  });

  group('пережатие фотографий', () {
    test('пережатие не увеличивает файл и не теряет байты', () async {
      // Шумная картинка, а не однотонная: однотонную PNG жмёт лучше любого
      // JPEG, и проверялась бы ветка «пережатие сделало хуже».
      final photo = img.Image(width: 900, height: 600);
      for (var y = 0; y < photo.height; y++) {
        for (var x = 0; x < photo.width; x++) {
          photo.setPixelRgb(x, y, (x * 7 + y * 13) % 256, (x * x) % 256, x ^ y);
        }
      }
      final source = Uint8List.fromList(img.encodePng(photo));

      final result = await compressPhoto(bytes: source, fileName: 'снимок.png');

      expect(result.bytes, isNotEmpty);
      expect(result.bytes.length, lessThanOrEqualTo(source.length));
      // Имя и тип описывают то, что действительно уехало, чем бы оно ни
      // оказалось: пережатым JPEG или нетронутым оригиналом.
      final jpeg =
          result.bytes[0] == 0xFF &&
          result.bytes[1] == 0xD8 &&
          result.bytes[2] == 0xFF;
      expect(result.contentType, jpeg ? 'image/jpeg' : 'image/png');
      expect(result.fileName, jpeg ? 'снимок.jpg' : 'снимок.png');
    });

    test('имя и тип всегда описывают то, что уехало', () async {
      // Крошечная картинка: пережатие сделало бы только хуже, оригинал
      // остаётся собой — и называется по-прежнему.
      final result = await compressPhoto(bytes: _png, fileName: 'иконка.png');
      expect(result.bytes, _png);
      expect(result.fileName, 'иконка.png');
      expect(result.contentType, 'image/png');
    });

    test('битые байты возвращаются как есть, а не теряются', () async {
      final junk = Uint8List.fromList(List.filled(64, 7));
      final result = await compressPhoto(bytes: junk, fileName: 'файл.bin');
      expect(result.bytes, junk);
    });
  });

  group('ссылки на расшаренные списки', () {
    test('узнаются в обеих формах и без повторов', () {
      const body =
          'вот мой список https://saobracaj.gleb.at/shared/ABCD1234 '
          'и он же saobracaj://shared/ABCD1234, а ещё '
          'https://saobracaj.gleb.at/shared/ZZZZ9999.';
      expect(sharedListCodesIn(body), ['ABCD1234', 'ZZZZ9999']);
    });

    test('слово внутри текста ссылкой не считается', () {
      expect(sharedListCodesIn('пишу про shared/ABCD1234'), isEmpty);
    });

    test('код неправильной длины не берётся', () {
      expect(
        sharedListCodesIn('https://saobracaj.gleb.at/shared/ABC'),
        isEmpty,
      );
    });
  });
}
