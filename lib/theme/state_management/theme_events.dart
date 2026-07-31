import 'package:flutter/material.dart';

sealed class ThemeEvent {}

/// Load the persisted accent + mode on startup.
class ThemeStarted extends ThemeEvent {}

class AccentChanged extends ThemeEvent {
  AccentChanged(this.index);
  final int index;
}

class ModeChanged extends ThemeEvent {
  ModeChanged(this.mode);
  final ThemeMode mode;
}
