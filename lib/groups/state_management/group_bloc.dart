import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

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
@injectable
class GroupBloc extends Bloc<GroupEditEvent, GroupState> {
  GroupBloc(this._groups, this._flags, @factoryParam String groupId)
    : super(GroupState(groupId: groupId)) {
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

  Future<void> _onOpened(GroupOpened event, Emitter<GroupState> emit) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final group = await _groups.load(state.groupId);
      if (emit.isDone) return;
      emit(
        state.copyWith(loading: false, group: group, notFound: group == null),
      );
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(loading: false, errorMessage: e.toString()));
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
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
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
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }
}
