import 'package:flutter/material.dart';

/// A selectable accent color used as the [ColorScheme] seed.
class AppAccent {
  const AppAccent(this.name, this.color);
  final String name;
  final Color color;
}

/// The palette the user can pick from in settings.
const List<AppAccent> kAppAccents = [
  AppAccent('blue', Colors.blueAccent),
  AppAccent('green', Colors.green),
  AppAccent('teal', Colors.teal),
  AppAccent('orange', Colors.deepOrange),
  AppAccent('purple', Colors.deepPurple),
  AppAccent('red', Colors.red),
];

/// Seed used for the "default" accent on platforms that do not expose a
/// dynamic (Material You) palette — iOS, web and older Android. On Android 12+
/// the wallpaper-based dynamic colors take precedence (see [ThemeState]).
const Color kDefaultSeedColor = Colors.blue;

/// Immutable UI-theme selection.
///
/// [accentIndex] is `null` for the "default" accent: on Android it resolves to
/// the system dynamic colors, and elsewhere to [kDefaultSeedColor]. A non-null
/// value is an index into [kAppAccents].
class ThemeState {
  const ThemeState({required this.accentIndex, required this.mode});

  final int? accentIndex;
  final ThemeMode mode;

  /// Whether the "default" (dynamic on Android) accent is selected.
  bool get isDefaultAccent => accentIndex == null;

  /// Fallback seed used when no dynamic palette is available.
  Color get seedColor =>
      accentIndex == null ? kDefaultSeedColor : kAppAccents[accentIndex!].color;

  ThemeState copyWith({int? accentIndex, ThemeMode? mode}) => ThemeState(
    accentIndex: accentIndex ?? this.accentIndex,
    mode: mode ?? this.mode,
  );

  /// [copyWith] cannot clear [accentIndex] back to `null`, so selecting the
  /// default accent goes through this explicit helper.
  ThemeState withDefaultAccent() =>
      ThemeState(accentIndex: null, mode: mode);
}
