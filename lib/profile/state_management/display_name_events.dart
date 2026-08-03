sealed class DisplayNameEvent {}

/// Load the current profile (dispatched once when the screen opens).
class DisplayNameStarted extends DisplayNameEvent {}

/// The user edited the text field. Updates the value immediately and schedules a
/// debounced autosave (see [DisplayNameSaveTick]).
class DisplayNameChanged extends DisplayNameEvent {
  DisplayNameChanged(this.value);
  final String value;
}

/// Internal, debounced save trigger — dispatched by [DisplayNameChanged] and
/// collapsed with rxdart's `debounceTime` so rapid typing produces one request.
class DisplayNameSaveTick extends DisplayNameEvent {
  DisplayNameSaveTick(this.value);
  final String value;
}
