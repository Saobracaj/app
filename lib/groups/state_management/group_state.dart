import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/group.dart';

part 'group_state.freezed.dart';

/// State of one group's screen: the roster, the owner's tools and whatever call
/// is currently in flight.
@freezed
abstract class GroupState with _$GroupState {
  const GroupState._();

  const factory GroupState({
    required String groupId,

    /// The group as last read; `null` until the first load finishes.
    Group? group,

    /// The first load is running.
    @Default(false) bool loading,

    /// The last read failed. Rendered inline with a retry, never as a snackbar
    /// — see [errorMessage].
    @Default(false) bool failed,

    /// That failure was a transport one, so the copy says "no connection".
    @Default(false) bool failedOffline,

    /// A write (rename, remove, invite, …) is running — the actions stay
    /// disabled meanwhile.
    @Default(false) bool busy,

    /// The group does not exist any more, or the caller is not a member of it.
    @Default(false) bool notFound,

    /// The group was deleted or left from this screen: the UI closes it.
    @Default(false) bool closed,

    /// The last failed *write* (rename, remove, invite, …), surfaced once as a
    /// snackbar and then cleared. A failed read never sets it: see [failed].
    String? errorMessage,
  }) = _GroupState;

  /// Whether the caller owns this group — the owner-only tools hang off this.
  bool get isOwner => group?.viewerIsOwner ?? false;

  /// The active invite code, or `null` when the owner has not issued one (or it
  /// expired).
  GroupInvite? get invite => group?.invite;

  /// Whether the current invite is still usable.
  bool get inviteIsLive {
    final expiresAt = invite?.expiresAt;
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }
}
