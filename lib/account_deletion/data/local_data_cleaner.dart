import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../db/dependencies.dart';

/// Wipes what the app keeps on the device: the local statistics database and
/// the shared-preferences caches (downloaded konspekts and explanations, the
/// question-lists cache, feature grants, one-off prompts, quiz preferences).
///
/// Used when a deleted account also asked for its local history to go. The
/// interface language and the theme are kept — they are device settings, not
/// the user's history, and losing them right after deleting an account would
/// read as a glitch.
@lazySingleton
class LocalDataCleaner {
  /// Preference keys that survive a wipe.
  static const keptKeys = {
    'locale', // easy_localization
    'theme_mode',
    'theme_accent_index',
  };

  /// Drops the local statistics database. Replaceable in tests, where the
  /// app-wide Drift database is not opened.
  @visibleForTesting
  Future<void> Function() clearStatistics = () => db.clearStatistics();

  Future<void> wipe() async {
    await clearStatistics();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (keptKeys.contains(key)) continue;
      await prefs.remove(key);
    }
  }
}
