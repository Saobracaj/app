import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_events.dart';
import 'theme_state.dart';

export 'theme_state.dart';

/// Persists the accent color and light/dark mode across launches.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc()
    : super(const ThemeState(accentIndex: null, mode: ThemeMode.system)) {
    on<ThemeStarted>(_onStarted);
    on<AccentChanged>(_onAccentChanged);
    on<DefaultAccentSelected>(_onDefaultAccentSelected);
    on<ModeChanged>(_onModeChanged);
    add(ThemeStarted());
  }

  static const _accentKey = 'theme_accent_index';
  static const _modeKey = 'theme_mode';

  /// Stored for the "default" accent so it round-trips through prefs.
  static const _defaultAccentValue = -1;

  Future<void> _onStarted(ThemeStarted event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_accentKey);
    final mode = _modeFromString(prefs.getString(_modeKey));
    emit(
      ThemeState(
        accentIndex: _sanitizeAccent(stored),
        mode: mode,
      ),
    );
  }

  Future<void> _onAccentChanged(
    AccentChanged event,
    Emitter<ThemeState> emit,
  ) async {
    if (event.index < 0 || event.index >= kAppAccents.length) return;
    emit(state.copyWith(accentIndex: event.index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, event.index);
  }

  Future<void> _onDefaultAccentSelected(
    DefaultAccentSelected event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.withDefaultAccent());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, _defaultAccentValue);
  }

  Future<void> _onModeChanged(
    ModeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(mode: event.mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, event.mode.name);
  }

  /// Resolves the persisted accent value: absent or the sentinel `-1` mean the
  /// "default" (dynamic) accent, any other value is clamped to a valid swatch.
  static int? _sanitizeAccent(int? stored) {
    if (stored == null || stored == _defaultAccentValue) return null;
    return stored.clamp(0, kAppAccents.length - 1);
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
