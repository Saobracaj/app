import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../core/network/error_messages.dart';
import '../../core/network/network_status.dart';
import '../../feature_flags/data/feature_flags_repository.dart';
import '../data/groups_repository.dart';
import 'group_events.dart';
import 'group_state.dart';

/// One group's screen: the roster, the owner's tools and the invite code.
///
/// Every rule the screen seems to enforce (the owner cannot leave, a group is
/// deletable only when empty, a removed member is banned) is really enforced by
/// the server inside a transaction — this Bloc only mirrors it so the buttons
/// match, and reads the group again after each write so the screen shows what
/// actually happened rather than what it hoped would.
///
/// The user's own list of groups lives in `GroupsBloc`; both read the same
/// [GroupsRepository], so a rename here reaches the home-screen card without
/// either of them knowing about the other.
///
/// A failed *read* is shown inline ([GroupState.failed]) and redone by itself
/// once [NetworkStatus] reports a reconnect — no snackbar. Only the writes the
/// user asked for report their failure, and a transport one reads as "no
/// connection to the server", never as the client's English placeholder.
@injectable
class GroupBloc extends Bloc<GroupEditEvent, GroupState> {
  GroupBloc(
    this._groups,
    this._flags,
    this._network,
    @factoryParam String groupId,
  ) : super(GroupState(groupId: groupId)) {
    on<GroupOpened>(_onOpened);
    on<GroupRenamed>(
      (event, emit) =>
          _write(emit, () => _groups.rename(state.groupId, event.name)),
    );
    on<GroupDeleted>(_onDeleted);
    on<GroupMemberRemoved>(
      (event, emit) =>
          _write(emit, () => _groups.removeMember(state.groupId, event.userId)),
    );
    on<GroupMemberUnbanned>(
      (event, emit) =>
          _write(emit, () => _groups.unbanMember(state.groupId, event.userId)),
    );
    on<GroupOwnershipTransferred>(
      (event, emit) => _write(
        emit,
        () => _groups.transferOwnership(state.groupId, event.userId),
      ),
    );
    on<GroupInviteRegenerated>(
      (event, emit) => _write(emit, () => _groups.createInvite(state.groupId)),
    );
    on<GroupInviteRevoked>(_onInviteRevoked);
    on<GroupErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final GroupsRepository _groups;
  final FeatureFlagsRepository _flags;
  final NetworkStatus _network;

  StreamSubscription<void>? _reconnectSubscription;

  @override
  Future<void> close() {
    _reconnectSubscription?.cancel();
    return super.close();
  }

  Future<void> _onOpened(GroupOpened event, Emitter<GroupState> emit) async {
    // Back online: re-read the group that could not be read while offline.
    _reconnectSubscription ??= _network.onReconnected.listen((_) {
      if (state.failed) add(const GroupOpened());
    });
    emit(state.copyWith(loading: true, failed: false));
    try {
      final group = await _groups.load(state.groupId);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          loading: false,
          failed: false,
          failedOffline: false,
          group: group,
          notFound: group == null,
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
      // Читать — не действие пользователя: сообщение не всплывает, а остаётся
      // на экране вместе с кнопкой «повторить».
      emit(
        state.copyWith(
          loading: false,
          failed: true,
          failedOffline: isNetworkError(e),
        ),
      );
    }
  }

  Future<void> _onDeleted(GroupDeleted event, Emitter<GroupState> emit) async {
    emit(state.copyWith(busy: true, errorMessage: null));
    try {
      await _groups.delete(state.groupId);
      // A group can carry feature grants of its own, so losing it may change
      // what the user is entitled to.
      await _flags.refreshFromBackend();
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, closed: true));
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, errorMessage: describeActionError(e)));
    }
  }

  Future<void> _onInviteRevoked(
    GroupInviteRevoked event,
    Emitter<GroupState> emit,
  ) {
    final token = state.invite?.token;
    if (token == null) return Future.value();
    return _write(emit, () => _groups.revokeInvite(token));
  }

  /// Run a write and re-read the group. The server is the only place that knows
  /// the resulting state (a removal also bans, a transfer swaps two roles), so
  /// nothing here is guessed from the answer.
  Future<void> _write(
    Emitter<GroupState> emit,
    Future<void> Function() action,
  ) async {
    emit(state.copyWith(busy: true, errorMessage: null));
    try {
      await action();
      final group = await _groups.load(state.groupId);
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, group: group, notFound: group == null));
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, errorMessage: describeActionError(e)));
    }
  }
}
