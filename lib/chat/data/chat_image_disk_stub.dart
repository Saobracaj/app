import 'dart:typed_data';

import 'chat_image_disk.dart';

/// Веб: файловой системы нет, кэш живёт только в памяти процесса.
class _NoDisk implements ChatImageDisk {
  const _NoDisk();

  @override
  Future<Uint8List?> read(String id) async => null;

  @override
  Future<void> write(String id, Uint8List bytes) async {}

  @override
  Future<void> clear() async {}
}

ChatImageDisk createChatImageDisk() => const _NoDisk();
