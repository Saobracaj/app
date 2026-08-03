import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'quiz_colors.dart';

/// The frozen palette of the real Serbian theory-exam software.
///
/// **These values are intentionally exempt from the app's design system.** They
/// do not follow the user's accent, they do not follow the light/dark setting
/// and they are never harmonised with the Material You palette — the whole
/// point of the "buttons like in the exam" option is that the screen looks
/// exactly like the machine the candidate will sit in front of. Treat any
/// mismatch with the rest of the app as intended, and change a value here only
/// if the real examination software changed.
abstract final class ExamPalette {
  /// Header chip ("Питање: 1 / 40") and the hint lines under it.
  static const Color header = Color(0xFF2C6AA0);

  /// Navigation buttons ("Претходно питање" / "Следеће питање").
  static const Color navigation = Color(0xFF428BCA);

  /// Destructive action ("Крај испита").
  static const Color danger = Color(0xFFD9534F);

  /// The report button ("Извештај") — light amber with brown text.
  static const Color report = Color(0xFFFEE188);
  static const Color onReport = Color(0xFF946331);

  /// Reveal-the-answer button, only present in training mode.
  static const Color success = Color(0xFF629B58);

  /// The countdown chip, which the real software renders on black.
  static const Color timer = Color(0xFF000000);

  /// Page background and the text on it.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF212121);

  /// Answer feedback, shown only when the training option "show the correct
  /// answer" is on.
  static const Color correct = Color(0xFF3C763D);
  static const Color correctContainer = Color(0xFFDFF0D8);
  static const Color wrong = Color(0xFFA94442);
  static const Color wrongContainer = Color(0xFFF2DEDE);

  /// Neutral borders and an unanswered question in the report table.
  static const Color outline = Color(0xFF9E9E9E);
  static const Color unanswered = Color(0xFFEEEEEE);
}

/// The theme applied to the exam simulation while "buttons like in the exam" is
/// enabled. Always light, always the same, regardless of the user's settings.
///
/// Built once at first use — it depends on nothing.
final ThemeData examTheme = _buildExamTheme();

ThemeData _buildExamTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: ExamPalette.header,
    onPrimary: Colors.white,
    primaryContainer: ExamPalette.navigation,
    onPrimaryContainer: Colors.white,
    secondary: ExamPalette.navigation,
    onSecondary: Colors.white,
    error: ExamPalette.danger,
    onError: Colors.white,
    surface: ExamPalette.surface,
    onSurface: ExamPalette.onSurface,
    surfaceContainerHighest: ExamPalette.unanswered,
    onSurfaceVariant: ExamPalette.onSurface,
    outline: ExamPalette.outline,
    outlineVariant: ExamPalette.outline,
  );

  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: kAppFontFamily,
    useMaterial3: true,
  );

  return base.copyWith(
    // The exam machine has no tinted elevation and no rounded Material 3
    // surfaces; keep everything flat and square-ish.
    scaffoldBackgroundColor: ExamPalette.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: ExamPalette.surface,
      foregroundColor: ExamPalette.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(color: ExamPalette.outline),
    extensions: const <ThemeExtension<dynamic>>[
      QuizColors(
        correct: ExamPalette.correct,
        onCorrect: Colors.white,
        correctContainer: ExamPalette.correctContainer,
        onCorrectContainer: ExamPalette.correct,
        wrong: ExamPalette.wrong,
        onWrong: Colors.white,
        wrongContainer: ExamPalette.wrongContainer,
        onWrongContainer: ExamPalette.wrong,
        warning: ExamPalette.onReport,
        onWarning: Colors.white,
        warningContainer: ExamPalette.report,
        onWarningContainer: ExamPalette.onReport,
        info: ExamPalette.header,
        onInfo: Colors.white,
        infoContainer: ExamPalette.header,
        onInfoContainer: Colors.white,
        unanswered: ExamPalette.unanswered,
        onUnanswered: ExamPalette.onSurface,
      ),
    ],
  );
}
