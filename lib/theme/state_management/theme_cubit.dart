import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Persists the accent color and light/dark mode across launches.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit()
    : super(const ThemeState(accentIndex: 0, mode: ThemeMode.system)) {
    _load();
  }

  static const _accentKey = 'theme_accent_index';
  static const _modeKey = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final accent = prefs.getInt(_accentKey) ?? 0;
    final mode = _modeFromString(prefs.getString(_modeKey));
    emit(
      ThemeState(
        accentIndex: accent.clamp(0, kAppAccents.length - 1),
        mode: mode,
      ),
    );
  }

  Future<void> setAccent(int index) async {
    if (index < 0 || index >= kAppAccents.length) return;
    emit(state.copyWith(accentIndex: index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, index);
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(state.copyWith(mode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  static ThemeMode _modeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
