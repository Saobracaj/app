import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

import '../../auth/data/graphql_client.dart';
import '../data/profile_repository.dart';
import '../domain/display_name_rules.dart';
import 'display_name_events.dart';
import 'display_name_state.dart';

/// Drives the Display Name settings screen.
///
/// The field edits update [DisplayNameState.value] immediately, while the save
/// is **debounced with rxdart** — every keystroke re-emits a
/// [DisplayNameSaveTick], and the transformer's `debounceTime` collapses a burst
/// of typing into a single `setDisplayName` request once the user pauses. The
/// value is validated client-side against the same rules as the backend before
/// any request goes out; once a name has been saved the field may never become
/// empty again.
@injectable
class DisplayNameBloc extends Bloc<DisplayNameEvent, DisplayNameState> {
  DisplayNameBloc(this._repository) : super(const DisplayNameState()) {
    on<DisplayNameStarted>(_onStarted);
    on<DisplayNameChanged>(_onChanged);
    on<DisplayNameSaveTick>(
      _onSaveTick,
      transformer: _debounce(const Duration(milliseconds: 600)),
    );
  }

  final ProfileRepository _repository;

  Future<void> _onStarted(
    DisplayNameStarted event,
    Emitter<DisplayNameState> emit,
  ) async {
    try {
      final profile = await _repository.myProfile();
      final name = profile.displayName ?? '';
      emit(state.copyWith(loading: false, value: name, savedValue: name));
    } catch (_) {
      // Offline / transient — start from an empty field, still editable.
      emit(state.copyWith(loading: false));
    }
  }

  void _onChanged(DisplayNameChanged event, Emitter<DisplayNameState> emit) {
    emit(state.copyWith(value: event.value, errorMessage: null, saved: false));
    add(DisplayNameSaveTick(event.value));
  }

  Future<void> _onSaveTick(
    DisplayNameSaveTick event,
    Emitter<DisplayNameState> emit,
  ) async {
    final trimmed = event.value.trim();

    // Nothing changed since the last successful save — skip the request.
    if (trimmed == state.savedValue) return;

    // An already-set name can never be cleared back to empty.
    if (trimmed.isEmpty) {
      if (state.hasSavedName) {
        emit(state.copyWith(errorMessage: 'Имя не может быть пустым'));
      }
      return;
    }

    final error = validateDisplayName(trimmed);
    if (error != null) {
      emit(state.copyWith(errorMessage: displayNameErrorMessage(error)));
      return;
    }

    emit(state.copyWith(saving: true, errorMessage: null, saved: false));
    try {
      final profile = await _repository.setDisplayName(trimmed);
      final saved = profile.displayName ?? trimmed;
      emit(state.copyWith(saving: false, saved: true, savedValue: saved));
    } on GraphqlException catch (e) {
      emit(state.copyWith(saving: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(saving: false, errorMessage: 'Не удалось сохранить'));
    }
  }
}

/// Debounce, then restart on a newer value: rxdart's `debounceTime` waits for a
/// pause in typing and `switchMap` cancels an in-flight save when a later
/// keystroke supersedes it.
EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
}
