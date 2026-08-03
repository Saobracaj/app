/// Client-side mirror of the backend display-name rules
/// (`saobracaj_backend/src/profile/model.rs::validate_display_name`): 2–40
/// characters, at most 5 whitespace-separated words, no control characters.
///
/// Keeping the same limits here lets the settings screen validate and show an
/// inline error before hitting the network; the backend remains authoritative
/// and re-validates on `setDisplayName`.
library;

import 'package:easy_localization/easy_localization.dart';

import '../../generated/locale_keys.g.dart';

const int displayNameMinLen = 2;
const int displayNameMaxLen = 40;
const int displayNameMaxWords = 5;

/// The outcome of validating a display name.
enum DisplayNameError { tooShort, tooLong, tooManyWords, controlChars }

/// Validate a trimmed display name against the backend rules. Returns `null`
/// when the (trimmed) value is acceptable, otherwise the first violated rule.
DisplayNameError? validateDisplayName(String raw) {
  final name = raw.trim();
  final len = name.runes.length;
  if (len < displayNameMinLen) return DisplayNameError.tooShort;
  if (len > displayNameMaxLen) return DisplayNameError.tooLong;
  if (name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >
      displayNameMaxWords) {
    return DisplayNameError.tooManyWords;
  }
  if (name.runes.any((r) => _isControl(r))) return DisplayNameError.controlChars;
  return null;
}

/// A localized, human message for a validation error, resolved from the current
/// locale's translations.
String displayNameErrorMessage(DisplayNameError error) => switch (error) {
  DisplayNameError.tooShort => LocaleKeys.comments_displayName_errorTooShort.tr(
    args: ['$displayNameMinLen'],
  ),
  DisplayNameError.tooLong => LocaleKeys.comments_displayName_errorTooLong.tr(
    args: ['$displayNameMaxLen'],
  ),
  DisplayNameError.tooManyWords =>
    LocaleKeys.comments_displayName_errorTooManyWords.tr(
      args: ['$displayNameMaxWords'],
    ),
  DisplayNameError.controlChars =>
    LocaleKeys.comments_displayName_errorControlChars.tr(),
};

bool _isControl(int rune) =>
    rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);
