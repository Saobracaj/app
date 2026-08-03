/// Client-side mirror of the backend display-name rules
/// (`saobracaj_backend/src/profile/model.rs::validate_display_name`): 2–40
/// characters, at most 5 whitespace-separated words, no control characters.
///
/// Keeping the same limits here lets the settings screen validate and show an
/// inline error before hitting the network; the backend remains authoritative
/// and re-validates on `setDisplayName`.
library;

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

/// A localized-ish, human message for a validation error (Russian, matching the
/// app's hardcoded-copy convention for the comments epic).
String displayNameErrorMessage(DisplayNameError error) => switch (error) {
  DisplayNameError.tooShort =>
    'Имя должно содержать не менее $displayNameMinLen символов',
  DisplayNameError.tooLong =>
    'Имя должно содержать не более $displayNameMaxLen символов',
  DisplayNameError.tooManyWords =>
    'Имя должно содержать не более $displayNameMaxWords слов',
  DisplayNameError.controlChars =>
    'Имя не должно содержать управляющих символов',
};

bool _isControl(int rune) =>
    rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);
