import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_events.dart';
import 'theme_state.dart';

export 'theme_state.dart';

/// Persists the accent color and light/dark mode across launches.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc()
    : super(const ThemeState(accentIndex: 0, mode: ThemeMode.light)) {
    on<ThemeStarted>(_onStarted);
    on<AccentChanged>(_onAccentChanged);
    on<ModeChanged>(_onModeChanged);
    add(ThemeStarted());
  }

  static const _accentKey = 'theme_accent_index';
  static const _modeKey = 'theme_mode';

  Future<void> _onStarted(ThemeStarted event, Emitter<ThemeState> emit) async {
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

  Future<void> _onAccentChanged(
    AccentChanged event,
    Emitter<ThemeState> emit,
  ) async {
    if (event.index < 0 || event.index >= kAppAccents.length) return;
    emit(state.copyWith(accentIndex: event.index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, event.index);
  }

  Future<void> _onModeChanged(
    ModeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    emit(state.copyWith(mode: event.mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, event.mode.name);
  }

  static ThemeMode _modeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      // No saved preference: keep a fixed scheme instead of following the OS,
      // so the interface colors don't change on their own until the user picks
      // a mode explicitly.
      default:
        return ThemeMode.light;
    }
  }
}
