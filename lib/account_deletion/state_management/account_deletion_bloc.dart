import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_events.dart';
import '../data/account_deletion_repository.dart';
import 'account_deletion_events.dart';
import 'account_deletion_state.dart';

/// Drives the account-deletion flow: load the preview, collect the content
/// choices and consents, e-mail the code, confirm. On success it hands over to
/// the app-wide [AuthBloc] (`AccountDeleted`), which wipes the device if asked
/// and ends the session — the token is dead on the server anyway.
@injectable
class AccountDeletionBloc
    extends Bloc<AccountDeletionEvent, AccountDeletionState> {
  AccountDeletionBloc(this._repository, this._auth)
    : super(const AccountDeletionState()) {
    on<AccountDeletionStarted>(_onStarted);
    on<DeletePublicCommentsToggled>(
      (e, emit) => emit(state.copyWith(deletePublicComments: e.value)),
    );
    on<DeleteSupportAttachmentsToggled>(
      (e, emit) => emit(state.copyWith(deleteSupportAttachments: e.value)),
    );
    on<DeleteSupportChatToggled>(
      (e, emit) => emit(state.copyWith(deleteSupportChat: e.value)),
    );
    on<DeleteGroupHistoryToggled>(
      (e, emit) => emit(state.copyWith(deleteGroupHistory: e.value)),
    );
    on<ClearLocalDataToggled>(
      (e, emit) => emit(state.copyWith(clearLocalData: e.value)),
    );
    on<AcceptIrreversibleToggled>(
      (e, emit) => emit(state.copyWith(acceptIrreversible: e.value)),
    );
    on<AcceptSubscriptionLossToggled>(
      (e, emit) => emit(state.copyWith(acceptSubscriptionLoss: e.value)),
    );
    on<RequestCodePressed>(_onRequestCode);
    on<ResendCodePressed>(_onResendCode);
    on<BackToOptionsPressed>(
      (e, emit) => emit(
        state.copyWith(
          step: AccountDeletionStep.options,
          code: '',
          errorMessage: null,
        ),
      ),
    );
    on<CodeChanged>(
      (e, emit) => emit(state.copyWith(code: e.code, errorMessage: null)),
    );
    on<ConfirmDeletePressed>(_onConfirm);
  }

  final AccountDeletionRepository _repository;
  final AuthBloc _auth;

  Future<void> _onStarted(
    AccountDeletionStarted event,
    Emitter<AccountDeletionState> emit,
  ) async {
    emit(state.copyWith(loading: true, loadError: null));
    try {
      final preview = await _repository.preview();
      emit(state.copyWith(loading: false, preview: preview));
    } on GraphqlException catch (e) {
      emit(state.copyWith(loading: false, loadError: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, loadError: e.toString()));
    }
  }

  Future<void> _onRequestCode(
    RequestCodePressed event,
    Emitter<AccountDeletionState> emit,
  ) async {
    if (!state.canRequestCode) return;
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      await _repository.requestCode();
      emit(
        state.copyWith(
          inProgress: false,
          step: AccountDeletionStep.code,
          code: '',
          codeSentTick: state.codeSentTick + 1,
        ),
      );
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }

  Future<void> _onResendCode(
    ResendCodePressed event,
    Emitter<AccountDeletionState> emit,
  ) async {
    if (state.inProgress) return;
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      await _repository.requestCode();
      emit(
        state.copyWith(inProgress: false, codeSentTick: state.codeSentTick + 1),
      );
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }

  Future<void> _onConfirm(
    ConfirmDeletePressed event,
    Emitter<AccountDeletionState> emit,
  ) async {
    if (!state.canConfirm) return;
    emit(state.copyWith(inProgress: true, errorMessage: null));
    try {
      final deleted = await _repository.deleteAccount(
        code: state.code.trim(),
        deletePublicComments: state.deletePublicComments,
        deleteSupportAttachments: state.deletesSupportAttachments,
        deleteSupportChat: state.deleteSupportChat,
        deleteGroupHistory: state.deleteGroupHistory,
        acceptIrreversible: state.acceptIrreversible,
        acceptSubscriptionLoss: state.acceptSubscriptionLoss,
      );
      if (!deleted) {
        emit(state.copyWith(inProgress: false, errorMessage: 'not deleted'));
        return;
      }
      // Publish `deleted` before the session ends, so the page shows the
      // farewell instead of reacting to the sign-out as a redirect.
      emit(state.copyWith(inProgress: false, deleted: true));
      _auth.add(AccountDeleted(clearLocalData: state.clearLocalData));
    } on GraphqlException catch (e) {
      emit(state.copyWith(inProgress: false, errorMessage: e.message));
    }
  }
}
