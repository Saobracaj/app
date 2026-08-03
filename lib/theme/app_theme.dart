import 'package:flutter/material.dart';

import 'quiz_colors.dart';

/// The bundled UI typeface. Shipped in `assets/fonts/` (see `pubspec.yaml`)
/// rather than fetched at runtime by `google_fonts`: the quiz itself works
/// entirely offline, so the type must too. The four weights cover Latin,
/// Serbian Latin (ć, č, đ, š, ž) and Cyrillic (including Ђ, Ћ, Џ, њ).
const String kAppFontFamily = 'Inter';

/// The single place the app's [ThemeData] is assembled.
///
/// Takes a fully-resolved [ColorScheme] — seeded from the user's accent, or the
/// harmonised platform palette on Android 12+ — and layers on the component
/// themes plus the semantic [QuizColors] extension, so screens never have to
/// hand-tune colours inline.
ThemeData buildAppTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, fontFamily: kAppFontFamily);

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[QuizColors.from(scheme)],

    appBarTheme: const AppBarTheme(centerTitle: false),

    // A single elevation story for grouped content: the tinted container level
    // instead of a drop shadow, per Material 3.
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Bottom navigation: the labels stay visible so the five destinations are
    // readable at a glance in all three locales.
    navigationBarTheme: const NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    // Buttons keep Material's minimum 48dp tap height in every variant, which
    // the default dense sizing does not guarantee once a small label is used.
    filledButtonTheme: FilledButtonThemeData(style: _buttonStyle()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle()),
    textButtonTheme: TextButtonThemeData(style: _buttonStyle()),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

ButtonStyle _buttonStyle() => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(const Size(64, 48)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
);
