import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/auth_repository.dart';
import '../../data/graphql_client.dart';
import '../auth_cubit.dart';
import 'reset_password_events.dart';
import 'reset_password_state.dart';

/// Two-step password reset: request a code by email ([SendCodePressed]), then
/// set a new password with that code ([ConfirmPressed]). On success the user is
/// logged in via the app-wide [AuthCubit].
@injectable
class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc(this._repository, this._authCubit)
      : super(const ResetPasswordState()) {
    on<EmailChanged>((e, emit) => emit(state.copyWith(email: e.email)));
    on<CodeChanged>((e, emit) => emit(state.copyWith(code: e.code)));
    on<NewPasswordChanged>(
      (e, emit) => emit(state.copyWith(newPassword: e.newPassword)),
    );
    on<SendCodePressed>(_onSendCode);
    on<ConfirmPressed>(_onConfirm);
  }

  final AuthRepository _repository;
  final AuthCubit _authCubit;

  Future<void> _onSendCode(
    SendCodePressed event,
    Emitter<ResetPasswordState> emit,
  ) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      await _repository.requestPasswordReset(state.email.trim());
      emit(state.copyWith(inProgress: false, codeSent: true));
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }

  Future<void> _onConfirm(
    ConfirmPressed event,
    Emitter<ResetPasswordState> emit,
  ) async {
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      await _repository.confirmPasswordReset(
        state.email.trim(),
        state.code.trim(),
        state.newPassword,
      );
      await _authCubit.onAuthenticated();
      emit(state.copyWith(inProgress: false, loggedIn: true));
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }
}
