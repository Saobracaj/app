import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

/// Когда приложение установлено: Android — `firstInstallTime` пакета, iOS —
/// дата создания каталога документов приложения. Обновление ни то, ни другое
/// не сдвигает, поэтому по этому времени бэкенд отличает новую установку от
/// давней, обновившейся до версии с атрибуцией.
Future<DateTime?> readInstalledAt() async {
  try {
    return (await PackageInfo.fromPlatform()).installTime?.toUtc();
  } catch (e) {
    debugPrint('Attribution: install time unavailable: $e');
    return null;
  }
}

/// Install referrer из Google Play — строка `utm_source=…&click_id=…`, если
/// приложение поставили по нашей ссылке. Только Android; `null`, если стора
/// нет (сборка поставлена мимо Play) или он не ответил.
Future<String?> readPlayReferrer() async {
  if (!Platform.isAndroid) return null;
  try {
    final details = await PlayInstallReferrer.installReferrer.timeout(
      const Duration(seconds: 10),
    );
    return details.installReferrer;
  } catch (e) {
    debugPrint('Attribution: Play install referrer unavailable: $e');
    return null;
  }
}

/// Идентификатор клика, с которым открыта веб-версия. На мобильных его нет.
String? readWebClickId() => null;

/// Платформа в терминах бэкенда (`LinkPlatform`).
String launchPlatform() => Platform.isIOS ? 'IOS' : 'ANDROID';
