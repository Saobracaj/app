import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/auth_repository.dart';
import '../../data/graphql_client.dart';
import 'register_events.dart';
import 'register_state.dart';

/// Drives the email + password registration screen. When the back-end requires
/// email confirmation the page is routed to the code-confirmation screen;
/// otherwise the repository publishes the authenticated session on its stream
/// (picked up by the app-wide `AuthBloc`).
@injectable
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._repository) : super(const RegisterState()) {
    on<EmailChanged>((e, emit) => emit(state.copyWith(email: e.email)));
    on<PasswordChanged>((e, emit) => emit(state.copyWith(password: e.password)));
    on<TogglePasswordVisibility>(
      (e, emit) => emit(state.copyWith(obscurePassword: !state.obscurePassword)),
    );
    on<SubmitPressed>(_onSubmit);
  }

  final AuthRepository _repository;

  Future<void> _onSubmit(
    SubmitPressed event,
    Emitter<RegisterState> emit,
  ) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    final email = state.email.trim();
    try {
      final tokens = await _repository.register(
        email,
        state.password,
        language: event.language,
      );
      if (tokens.authenticated) {
        emit(state.copyWith(inProgress: false, loggedIn: true));
      } else {
        emit(state.copyWith(inProgress: false, needsConfirmationFor: email));
      }
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }
}
