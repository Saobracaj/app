import 'dart:io';

/// `Android 14 (SP1A.210812.016)`, `iOS 17.5.1`, `macOS 15.5` — как их
/// сообщает сама платформа.
String? describeOs() {
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } catch (_) {
    // На всякий случай: сломанная аналитика не должна ронять запуск.
    return null;
  }
}
