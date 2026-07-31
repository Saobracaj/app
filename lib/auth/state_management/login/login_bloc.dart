import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/auth_repository.dart';
import '../../data/graphql_client.dart';
import 'login_events.dart';
import 'login_state.dart';

/// Drives the email + password login screen. On success the repository publishes
/// the authenticated session on its stream (picked up by the app-wide
/// `AuthBloc`); when the account isn't confirmed yet it signals the page to
/// route to the confirmation screen.
@injectable
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._repository) : super(const LoginState()) {
    on<EmailChanged>((e, emit) => emit(state.copyWith(email: e.email)));
    on<PasswordChanged>((e, emit) => emit(state.copyWith(password: e.password)));
    on<TogglePasswordVisibility>(
      (e, emit) => emit(state.copyWith(obscurePassword: !state.obscurePassword)),
    );
    on<SubmitPressed>(_onSubmit);
  }

  final AuthRepository _repository;

  Future<void> _onSubmit(SubmitPressed event, Emitter<LoginState> emit) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      final tokens = await _repository.login(
        state.email.trim(),
        state.password,
      );
      if (!tokens.authenticated) {
        emit(state.copyWith(
          inProgress: false,
          needsConfirmationFor: state.email.trim(),
        ));
        return;
      }
      emit(state.copyWith(inProgress: false, loggedIn: true));
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }
}
