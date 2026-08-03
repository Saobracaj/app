import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Semantic colours the quiz needs but Material's [ColorScheme] does not define:
/// answer correctness, "not answered yet", and the informational/warning accents
/// used for hints such as "Број поена" or "Број потребних одговора".
///
/// The colours are *derived*, never fixed: each role starts from a reference hue
/// (green / red / amber / blue), is harmonised towards the active
/// [ColorScheme.primary] — so it shifts with a user-picked accent and with the
/// Android 12+ wallpaper palette — and is then expanded into a tonal group via
/// [ColorScheme.fromSeed] at the scheme's own brightness. That is what keeps the
/// pair (`container`, `onContainer`) legible in both the light and the dark
/// theme, which the previous hardcoded `Color(0x2200ff00)` overlays were not.
///
/// Read it with `Theme.of(context).quiz` (see [QuizColorsX]).
///
/// The one place these do **not** apply is the exam simulation with
/// "buttons like in the exam" enabled — that screen deliberately replicates the
/// real examination software and uses the frozen palette in `exam_theme.dart`.
@immutable
class QuizColors extends ThemeExtension<QuizColors> {
  const QuizColors({
    required this.correct,
    required this.onCorrect,
    required this.correctContainer,
    required this.onCorrectContainer,
    required this.wrong,
    required this.onWrong,
    required this.wrongContainer,
    required this.onWrongContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.unanswered,
    required this.onUnanswered,
  });

  /// A correct answer: the emphatic colour (indicator dots, chart bars).
  final Color correct;
  final Color onCorrect;

  /// A correct answer as a *surface* — the row highlight behind a choice.
  final Color correctContainer;
  final Color onCorrectContainer;

  /// A wrong answer, same two levels of emphasis.
  final Color wrong;
  final Color onWrong;
  final Color wrongContainer;
  final Color onWrongContainer;

  /// "Needs attention" — a marked question, a partially-correct result.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Informational accent for the question's metadata lines (points, required
  /// number of answers). Replaces the hardcoded `Color(0xff2c6aa0)`.
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// A question the user has not answered yet — deliberately neutral, so it
  /// recedes behind the answered ones.
  final Color unanswered;
  final Color onUnanswered;

  /// Reference hues. Chosen to stay distinguishable after harmonisation with an
  /// arbitrary accent; they are seeds, not the rendered colours.
  static const _correctSeed = Color(0xFF2E7D32);
  static const _wrongSeed = Color(0xFFC62828);
  static const _warningSeed = Color(0xFFF9A825);
  static const _infoSeed = Color(0xFF2C6AA0);

  /// Builds the set for [scheme], harmonising every role towards its primary.
  factory QuizColors.from(ColorScheme scheme) {
    final brightness = scheme.brightness;
    ColorScheme tonesOf(Color seed) => ColorScheme.fromSeed(
      seedColor: seed.harmonizeWith(scheme.primary),
      brightness: brightness,
    );

    final correct = tonesOf(_correctSeed);
    final wrong = tonesOf(_wrongSeed);
    final warning = tonesOf(_warningSeed);
    final info = tonesOf(_infoSeed);

    return QuizColors(
      correct: correct.primary,
      onCorrect: correct.onPrimary,
      correctContainer: correct.primaryContainer,
      onCorrectContainer: correct.onPrimaryContainer,
      wrong: wrong.primary,
      onWrong: wrong.onPrimary,
      wrongContainer: wrong.primaryContainer,
      onWrongContainer: wrong.onPrimaryContainer,
      warning: warning.primary,
      onWarning: warning.onPrimary,
      warningContainer: warning.primaryContainer,
      onWarningContainer: warning.onPrimaryContainer,
      info: info.primary,
      onInfo: info.onPrimary,
      infoContainer: info.primaryContainer,
      onInfoContainer: info.onPrimaryContainer,
      // The neutral role comes from the scheme itself so it always matches the
      // surrounding surface.
      unanswered: scheme.surfaceContainerHighest,
      onUnanswered: scheme.onSurfaceVariant,
    );
  }

  @override
  QuizColors copyWith({
    Color? correct,
    Color? onCorrect,
    Color? correctContainer,
    Color? onCorrectContainer,
    Color? wrong,
    Color? onWrong,
    Color? wrongContainer,
    Color? onWrongContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? unanswered,
    Color? onUnanswered,
  }) {
    return QuizColors(
      correct: correct ?? this.correct,
      onCorrect: onCorrect ?? this.onCorrect,
      correctContainer: correctContainer ?? this.correctContainer,
      onCorrectContainer: onCorrectContainer ?? this.onCorrectContainer,
      wrong: wrong ?? this.wrong,
      onWrong: onWrong ?? this.onWrong,
      wrongContainer: wrongContainer ?? this.wrongContainer,
      onWrongContainer: onWrongContainer ?? this.onWrongContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      unanswered: unanswered ?? this.unanswered,
      onUnanswered: onUnanswered ?? this.onUnanswered,
    );
  }

  @override
  QuizColors lerp(ThemeExtension<QuizColors>? other, double t) {
    if (other is! QuizColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return QuizColors(
      correct: c(correct, other.correct),
      onCorrect: c(onCorrect, other.onCorrect),
      correctContainer: c(correctContainer, other.correctContainer),
      onCorrectContainer: c(onCorrectContainer, other.onCorrectContainer),
      wrong: c(wrong, other.wrong),
      onWrong: c(onWrong, other.onWrong),
      wrongContainer: c(wrongContainer, other.wrongContainer),
      onWrongContainer: c(onWrongContainer, other.onWrongContainer),
      warning: c(warning, other.warning),
      onWarning: c(onWarning, other.onWarning),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      info: c(info, other.info),
      onInfo: c(onInfo, other.onInfo),
      infoContainer: c(infoContainer, other.infoContainer),
      onInfoContainer: c(onInfoContainer, other.onInfoContainer),
      unanswered: c(unanswered, other.unanswered),
      onUnanswered: c(onUnanswered, other.onUnanswered),
    );
  }
}

/// `Theme.of(context).quiz` — the semantic quiz palette of the active theme.
///
/// Every [ThemeData] built by `buildAppTheme` / `buildExamTheme` registers a
/// [QuizColors], so the fallback below only ever fires for a bare `ThemeData()`
/// in a test or a preview.
extension QuizColorsX on ThemeData {
  QuizColors get quiz =>
      extension<QuizColors>() ?? QuizColors.from(colorScheme);
}
