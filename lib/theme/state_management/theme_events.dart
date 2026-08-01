import 'package:flutter/material.dart';

sealed class ThemeEvent {}

/// Load the persisted accent + mode on startup.
class ThemeStarted extends ThemeEvent {}

/// Pick one of the [kAppAccents] swatches.
class AccentChanged extends ThemeEvent {
  AccentChanged(this.index);
  final int index;
}

/// Reset the accent to "default" (dynamic colors on Android).
class DefaultAccentSelected extends ThemeEvent {}

class ModeChanged extends ThemeEvent {
  ModeChanged(this.mode);
  final ThemeMode mode;
}
