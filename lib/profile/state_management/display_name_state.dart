import 'package:freezed_annotation/freezed_annotation.dart';

part 'display_name_state.freezed.dart';

/// State of the Display Name settings screen.
///
/// [value] is the live text being edited; [savedValue] is the last value
/// successfully persisted to the backend (used to decide whether an empty field
/// is allowed — once a name is set it can never be cleared). [saving] shows the
/// autosave indicator; [errorMessage] is an inline validation/network error.
@freezed
abstract class DisplayNameState with _$DisplayNameState {
  const factory DisplayNameState({
    @Default(true) bool loading,
    @Default('') String value,
    @Default('') String savedValue,
    @Default(false) bool saving,
    @Default(false) bool saved,
    String? errorMessage,
  }) = _DisplayNameState;

  const DisplayNameState._();

  /// Whether a name has ever been saved (so the field must not become empty).
  bool get hasSavedName => savedValue.trim().isNotEmpty;
}
