import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../data/auth_repository.dart';
import '../../data/graphql_client.dart';
import '../auth_cubit.dart';
import 'confirm_code_events.dart';
import 'confirm_code_state.dart';

/// Confirms the 6-digit email code sent after registration. Auto-submits as soon
/// as the full code is entered, and can resend the code. On success the session
/// is handed to the app-wide [AuthCubit].
@injectable
class ConfirmCodeBloc extends Bloc<ConfirmCodeEvent, ConfirmCodeState> {
  ConfirmCodeBloc(
    this._repository,
    this._authCubit,
    @factoryParam this.email,
  ) : super(const ConfirmCodeState()) {
    on<CodeChanged>(_onCodeChanged);
    on<SubmitPressed>(_onSubmit);
    on<ResendPressed>(_onResend);
  }

  final AuthRepository _repository;
  final AuthCubit _authCubit;
  final String email;

  void _onCodeChanged(CodeChanged event, Emitter<ConfirmCodeState> emit) {
    final code = event.code.trim();
    emit(state.copyWith(code: code, errorMessage: null));
    // Auto-verify once the full 6-digit code is present (owncup behaviour).
    if (code.length == 6 && !state.inProgress) {
      add(SubmitPressed());
    }
  }

  Future<void> _onSubmit(
    SubmitPressed event,
    Emitter<ConfirmCodeState> emit,
  ) async {
    if (state.inProgress) return;
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      await _repository.confirmEmail(email, state.code.trim());
      await _authCubit.onAuthenticated();
      emit(state.copyWith(inProgress: false, loggedIn: true));
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }

  Future<void> _onResend(
    ResendPressed event,
    Emitter<ConfirmCodeState> emit,
  ) async {
    try {
      await _repository.resendConfirmationCode(email);
      emit(state.copyWith(resentTick: state.resentTick + 1));
    } on GraphqlException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    }
  }
}
