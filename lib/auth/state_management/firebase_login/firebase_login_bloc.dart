import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/auth_repository.dart';
import '../../data/graphql_client.dart';
import 'firebase_login_events.dart';
import 'firebase_login_state.dart';

/// Drives Google / Apple sign-in. Firebase is used only to obtain an OAuth ID
/// token; that token is exchanged for our own session via
/// [AuthRepository.firebaseAuth], which then publishes the authenticated session
/// on its stream (picked up by the app-wide `AuthBloc`). Same flow as owncup's
/// `FirebaseLoginBloc`.
@injectable
class FirebaseLoginBloc extends Bloc<FirebaseLoginEvent, FirebaseLoginState> {
  FirebaseLoginBloc(this._repository) : super(const FirebaseLoginState()) {
    on<FirebaseAuthReceived>(_onAuthReceived);
  }

  final AuthRepository _repository;

  Future<void> _onAuthReceived(
    FirebaseAuthReceived event,
    Emitter<FirebaseLoginState> emit,
  ) async {
    final authState = event.authState;
    if (authState is fb_ui_auth.SignedIn) {
      final idToken = await authState.user?.getIdToken(true);
      if (idToken == null) {
        _pulse(emit, state.copyWith(shouldLogOut: true));
        return;
      }
      emit(state.copyWith(isBusy: true, errorMessage: null));
      try {
        final tokens = await _repository.firebaseAuth(idToken);
        _pulse(
          emit,
          state.copyWith(
            isBusy: false,
            success: tokens.authenticated,
            shouldLogOut: true,
          ),
        );
      } on GraphqlException catch (e) {
        _pulse(
          emit,
          state.copyWith(
            isBusy: false,
            errorMessage: e.message,
            shouldLogOut: true,
          ),
        );
      }
    } else if (authState is fb_ui_auth.AuthFailed) {
      // Cancelled / provider error: just reset the Firebase session so the next
      // tap starts clean. The technical exception isn't surfaced to the user.
      _pulse(emit, state.copyWith(isBusy: false, shouldLogOut: true));
    }
  }

  /// Emit a one-shot effect state, then immediately clear the effect flags so
  /// the same effect isn't re-run on a later rebuild.
  void _pulse(Emitter<FirebaseLoginState> emit, FirebaseLoginState effect) {
    emit(effect);
    emit(
      effect.copyWith(shouldLogOut: false, success: false, errorMessage: null),
    );
  }
}
