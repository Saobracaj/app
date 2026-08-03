/// Russian relative-time formatting for comment timestamps
/// ("только что", "5 минут назад", "2 часа назад", "месяц назад").
///
/// `get_time_ago` ships no Russian/Serbian locale, and the product spec asks
/// specifically for this Russian format, so it is implemented here with correct
/// Russian plural forms.
library;

String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  var diff = current.difference(time);
  if (diff.isNegative) diff = Duration.zero; // clamp clock skew

  final seconds = diff.inSeconds;
  if (seconds < 45) return 'только что';

  final minutes = diff.inMinutes;
  if (minutes < 60) return '${_plural(minutes, _minute)} назад';

  final hours = diff.inHours;
  if (hours < 24) return '${_plural(hours, _hour)} назад';

  final days = diff.inDays;
  if (days < 30) return '${_plural(days, _day)} назад';

  final months = days ~/ 30;
  if (months < 12) return '${_plural(months, _month)} назад';

  final years = days ~/ 365;
  return '${_plural(years, _year)} назад';
}

// Plural form triples: [one, few, many] (2 минуты / 5 минут).
const _minute = ['минуту', 'минуты', 'минут'];
const _hour = ['час', 'часа', 'часов'];
const _day = ['день', 'дня', 'дней'];
const _month = ['месяц', 'месяца', 'месяцев'];
const _year = ['год', 'года', 'лет'];

String _plural(int n, List<String> forms) => '$n ${_form(n, forms)}';

/// Select the Russian plural form for [n].
String _form(int n, List<String> forms) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return forms[0];
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return forms[1];
  return forms[2];
}
