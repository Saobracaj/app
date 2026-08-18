/// Пережатие фотографий в JPEG **на устройстве**, перед загрузкой.
///
/// Из двух возможных мест — бэкенд или клиент — выбран клиент: так пользователь
/// не платит трафиком за оригинал (12-мегапиксельный HEIC/PNG легко весит
/// 10 МБ), сервер не получает нового пути обработки бинарей и не появляется
/// состояния «файл уже лежит, но ещё не пережат». Цена — несколько сотен
/// миллисекунд в фоновом изолате.
///
/// Двухступенчато и намеренно:
///
/// 1. `image_picker` сам просят отдать уменьшенный JPEG (`maxWidth`/
///    `imageQuality`) — на Android и iOS это делает системный кодек, почти
///    бесплатно;
/// 2. всё, что после этого всё ещё не JPEG или всё ещё большое, дожимается
///    здесь чистым Dart'ом ([img]) — этот путь нужен вебу, где
///    `image_picker_for_web` параметры качества игнорирует.
///
/// Файлы, приложенные пунктом «Файл», через компрессор не проходят: они должны
/// дойти до получателя байт в байт.
library;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;


/// Максимальная сторона фотографии после пережатия. 2048 px хватает, чтобы на
/// любом экране рассмотреть скриншот приложения, и вчетверо-впятеро уменьшает
/// вес против оригинала с современной камеры.
const int kPhotoMaxDimension = 2048;

/// Качество JPEG. 85 — общепринятая граница, за которой артефакты становятся
/// заметны, а выигрыш в размере — нет.
const int kPhotoJpegQuality = 85;

/// Байты меньше этого порога не трогаем совсем, если это уже JPEG: пережимать
/// маленькую картинку — только терять качество.
const int _skipBelowBytes = 512 * 1024;

/// Фотография, готовая к загрузке.
class CompressedPhoto {
  const CompressedPhoto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

/// Привести выбранную фотографию к JPEG.
///
/// Никогда не бросает из-за самой картинки: если декодировать не удалось (какой
/// -нибудь экзотический формат, который `image` не знает), возвращаются
/// исходные байты — отправить оригинал лучше, чем не отправить ничего.
Future<CompressedPhoto> compressPhoto({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (_isJpeg(bytes) && bytes.length <= _skipBelowBytes) {
    return CompressedPhoto(
      bytes: bytes,
      fileName: _jpegName(fileName),
      contentType: 'image/jpeg',
    );
  }
  try {
    final encoded = await compute(_encodeJpeg, bytes);
    // Пережатие, которое сделало только хуже (уже оптимизированный JPEG),
    // выбрасываем: смысл был в размере.
    final best = encoded != null && encoded.length < bytes.length
        ? encoded
        : bytes;
    // Имя и тип всегда описывают то, что действительно уехало: если пережатие
    // отбросили, файл остаётся собой, и называть его `.jpg` было бы враньём.
    final jpeg = _isJpeg(best);
    return CompressedPhoto(
      bytes: best,
      fileName: jpeg ? _jpegName(fileName) : fileName,
      contentType: jpeg ? 'image/jpeg' : _contentTypeOf(fileName),
    );
  } catch (_) {
    return CompressedPhoto(
      bytes: bytes,
      fileName: fileName,
      contentType: _contentTypeOf(fileName),
    );
  }
}

/// Декодирование и кодирование — в изоляте: на большом снимке это десятки
/// миллионов пикселей, и в UI-потоке это заметная пауза.
Uint8List? _encodeJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longest > kPhotoMaxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? kPhotoMaxDimension : null,
          height: decoded.height > decoded.width ? kPhotoMaxDimension : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;
  return img.encodeJpg(resized, quality: kPhotoJpegQuality);
}

/// SOI-маркер JPEG.
bool _isJpeg(Uint8List bytes) =>
    bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

/// Имя с расширением `.jpg`: получатель скачивает файл под тем именем, которое
/// соответствует его содержимому.
String _jpegName(String fileName) {
  final name = fileName.trim().isEmpty ? 'photo' : fileName.trim();
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return '$base.jpg';
}

String _contentTypeOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot > 0 ? fileName.substring(dot + 1).toLowerCase() : '';
  return switch (ext) {
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'bmp' => 'image/bmp',
    _ => 'image/jpeg',
  };
}
