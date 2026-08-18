import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'chat_image_disk.dart';

/// Сколько байт кэша держим на диске. Сотня фотографий из чата — с большим
/// запасом; всё сверх этого вычищается, начиная с самых давно не читанных.
const int _maxDiskBytes = 128 * 1024 * 1024;

/// Мобильные платформы: файлы во временном каталоге приложения, по одному на
/// вложение. Имя файла — id вложения, поэтому смена подписанной ссылки не
/// заводит новой копии.
class _FileDisk implements ChatImageDisk {
  Directory? _dir;
  Future<Directory?>? _opening;

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _fileFor(id);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      // По времени последнего чтения потом решаем, что вычищать.
      unawaitedIgnore(file.setLastAccessed(DateTime.now()));
      return bytes;
    } catch (_) {
      // Битый файл кэша — не повод не показать картинку: скачаем заново.
      return null;
    }
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    final file = await _fileFor(id);
    if (file == null || bytes.isEmpty) return;
    try {
      await file.writeAsBytes(bytes, flush: false);
      await _prune();
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    final dir = await _directory();
    if (dir == null) return;
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
    _dir = null;
    _opening = null;
  }

  Future<File?> _fileFor(String id) async {
    final dir = await _directory();
    if (dir == null) return null;
    // id приходит от бэкенда, но имя файла всё равно нормализуем: чужой
    // идентификатор не должен уметь выйти из каталога кэша.
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (safe.isEmpty) return null;
    return File(p.join(dir.path, safe));
  }

  Future<Directory?> _directory() {
    final ready = _dir;
    if (ready != null) return Future.value(ready);
    return _opening ??= () async {
      try {
        final base = await getTemporaryDirectory();
        final dir = Directory(p.join(base.path, 'chat_images'));
        if (!await dir.exists()) await dir.create(recursive: true);
        return _dir = dir;
      } catch (_) {
        return null;
      }
    }();
  }

  /// Выбросить самые давно не читанные файлы, если кэш перерос лимит.
  Future<void> _prune() async {
    final dir = _dir;
    if (dir == null) return;
    final files = <File>[];
    var total = 0;
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      files.add(entry);
      total += await entry.length();
    }
    if (total <= _maxDiskBytes) return;
    final accessed = <String, DateTime>{};
    for (final file in files) {
      accessed[file.path] = (await file.stat()).accessed;
    }
    files.sort((a, b) => accessed[a.path]!.compareTo(accessed[b.path]!));
    for (final file in files) {
      if (total <= _maxDiskBytes) break;
      total -= await file.length();
      await file.delete();
    }
  }
}

/// `unawaited` без импорта `dart:async` ради одной строки — и с проглоченной
/// ошибкой: обновление времени доступа не должно ронять чтение кэша.
void unawaitedIgnore(Future<void> future) {
  future.then((_) {}, onError: (_) {});
}

ChatImageDisk createChatImageDisk() => _FileDisk();
