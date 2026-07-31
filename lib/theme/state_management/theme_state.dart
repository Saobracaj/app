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

/// Immutable UI-theme selection.
class ThemeState {
  const ThemeState({required this.accentIndex, required this.mode});

  final int accentIndex;
  final ThemeMode mode;

  Color get seedColor => kAppAccents[accentIndex].color;

  ThemeState copyWith({int? accentIndex, ThemeMode? mode}) => ThemeState(
    accentIndex: accentIndex ?? this.accentIndex,
    mode: mode ?? this.mode,
  );
}
