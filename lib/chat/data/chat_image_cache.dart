/// Кэш картинок чата — по **id вложения**, а не по ссылке.
///
/// Ссылки на вложения подписываются на пятнадцать минут, и каждое перечитывание
/// переписки выдаёт новые: для `Image.network` это каждый раз новая картинка, и
/// одна и та же фотография скачивалась заново при каждом пролистывании истории.
/// Идентичность фотографии задаёт id вложения — он и служит ключом и в памяти
/// (через штатный `ImageCache` Flutter), и на диске.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'chat_image_disk.dart';
import 'chat_image_disk_stub.dart'
    if (dart.library.io) 'chat_image_disk_io.dart';

/// [ImageProvider], который берёт байты из кэша и, только если их там нет, —
/// из сети по подписанной ссылке.
///
/// Ключ — идентификатор вложения, поэтому две подписанные ссылки на одну и ту
/// же фотографию — это одна запись в кэше, а не две.
@immutable
class CachedChatImage extends ImageProvider<ChatImageKey> {
  const CachedChatImage({
    required this.attachmentId,
    required this.url,
    this.scale = 1.0,
    this.decodeWidth,
  });

  /// Идентификатор вложения — он же ключ кэша.
  final String attachmentId;

  /// Подписанная ссылка, по которой качать, если в кэше пусто. Может протухнуть:
  /// тогда загрузка падает, вызывающая сторона просит подписать заново и строит
  /// провайдер с новой ссылкой — запись со сбоем `ImageCache` удаляет сам.
  final String url;

  final double scale;

  /// До какой ширины (в пикселях устройства) разжимать картинку.
  ///
  /// Плитка в пузыре — 240 логических точек, а снимок с телефона приезжает
  /// в полтора-две тысячи пикселей: разжатый целиком, он и декодируется дольше,
  /// и занимает в кэше в двадцать раз больше памяти. При быстрой прокрутке это
  /// как раз те кадры, которые пропадали. `null` — разжимать как есть, так
  /// делает полноэкранный просмотр, где нужно всё разрешение.
  final int? decodeWidth;

  @override
  Future<ChatImageKey> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(ChatImageKey(attachmentId, scale, decodeWidth));

  @override
  ImageStreamCompleter loadImage(
    ChatImageKey key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: key.scale,
      debugLabel: 'chat-image:$attachmentId',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await ChatImageStore.instance.bytes(
      attachmentId: attachmentId,
      url: url,
    );
    if (bytes.isEmpty) {
      throw StateError('empty image for attachment $attachmentId');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final width = decodeWidth;
    if (width == null) return decode(buffer);
    return decode(
      buffer,
      getTargetSize: (intrinsicWidth, intrinsicHeight) {
        // Уменьшаем, но никогда не увеличиваем: картинка меньше плитки должна
        // остаться собой.
        if (intrinsicWidth <= width) {
          return ui.TargetImageSize(
            width: intrinsicWidth,
            height: intrinsicHeight,
          );
        }
        final height = (intrinsicHeight * width / intrinsicWidth).round();
        return ui.TargetImageSize(width: width, height: height);
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CachedChatImage &&
      other.attachmentId == attachmentId &&
      other.scale == scale &&
      other.decodeWidth == decodeWidth;

  @override
  int get hashCode => Object.hash(attachmentId, scale, decodeWidth);
}

/// Ключ кэша: вложение, масштаб и ширина разжатия. Публичный, потому что им
/// параметризован [CachedChatImage].
///
/// Ширина входит в ключ намеренно: уменьшенная плитка и полноразмерный снимок —
/// это две разные картинки одного вложения, и подсунуть одну вместо другой
/// нельзя.
@immutable
class ChatImageKey {
  const ChatImageKey(this.id, this.scale, [this.decodeWidth]);

  final String id;
  final double scale;
  final int? decodeWidth;

  @override
  bool operator ==(Object other) =>
      other is ChatImageKey &&
      other.id == id &&
      other.scale == scale &&
      other.decodeWidth == decodeWidth;

  @override
  int get hashCode => Object.hash(id, scale, decodeWidth);
}

/// Байты вложений: диск (кроме веба) плюс защёлка от параллельных загрузок
/// одного и того же файла.
///
/// Синглтон, а не зависимость из getIt, потому что единственный его потребитель
/// — [CachedChatImage], который Flutter создаёт и уничтожает сам, без доступа к
/// контексту.
class ChatImageStore {
  ChatImageStore._();

  static final ChatImageStore instance = ChatImageStore._();

  /// Загрузки в полёте, по id вложения: две плитки одной фотографии (в ленте и
  /// в полноэкранном просмотре) качают её один раз.
  final Map<String, Future<Uint8List>> _inFlight = {};

  final ChatImageDisk _disk = createChatImageDisk();

  /// Для тестов: подменить HTTP-клиент.
  @visibleForTesting
  http.Client client = http.Client();

  /// Байты вложения — из кэша, иначе из сети (и тогда в кэш).
  Future<Uint8List> bytes({required String attachmentId, required String url}) {
    final running = _inFlight[attachmentId];
    if (running != null) return running;
    final future = _read(attachmentId, url);
    _inFlight[attachmentId] = future;
    return future.whenComplete(() => _inFlight.remove(attachmentId));
  }

  Future<Uint8List> _read(String attachmentId, String url) async {
    final cached = await _disk.read(attachmentId);
    if (cached != null) return cached;
    if (url.isEmpty) return Uint8List(0);
    final response = await client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', Uri.parse(url));
    }
    final bytes = response.bodyBytes;
    if (bytes.isNotEmpty) {
      // Запись в кэш не должна задерживать показ картинки.
      _disk.write(attachmentId, bytes).then((_) {}, onError: (_) {});
    }
    return bytes;
  }

  /// Забыть всё, что накопилось, — например, при выходе из аккаунта.
  Future<void> clear() => _disk.clear();

  /// Забыть незавершённые загрузки. Нужно тестам: там кадры прокручиваются
  /// вручную, начатая виджетом загрузка до конца не доходит, и следующий тест
  /// иначе получил бы из [_inFlight] будущее, которое никогда не завершится.
  @visibleForTesting
  void resetInFlight() => _inFlight.clear();
}
