/// Relative-time formatting for comment timestamps ("пре 5 мин",
/// "2 ч назад", "just now"), localized through `comments.time.*` keys.
///
/// `get_time_ago` ships no Russian/Serbian locale, so the thresholds live here
/// and the plural forms live in the translation files (CLDR rules — the app
/// runs EasyLocalization with `ignorePluralRules: false`).
library;

import 'package:easy_localization/easy_localization.dart';

import '../../generated/locale_keys.g.dart';

String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  var diff = current.difference(time);
  if (diff.isNegative) diff = Duration.zero; // clamp clock skew

  final seconds = diff.inSeconds;
  if (seconds < 45) return LocaleKeys.comments_time_justNow.tr();

  final minutes = diff.inMinutes;
  if (minutes < 60) return LocaleKeys.comments_time_minutes.plural(minutes);

  final hours = diff.inHours;
  if (hours < 24) return LocaleKeys.comments_time_hours.plural(hours);

  final days = diff.inDays;
  if (days < 30) return LocaleKeys.comments_time_days.plural(days);

  final months = days ~/ 30;
  if (months < 12) return LocaleKeys.comments_time_months.plural(months);

  final years = days ~/ 365;
  return LocaleKeys.comments_time_years.plural(years);
}
