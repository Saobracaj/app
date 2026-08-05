import 'package:freezed_annotation/freezed_annotation.dart';

import '../../profile/models/user_profile.dart';
import '../models/group.dart';

part 'groups_state.freezed.dart';

/// App-wide state of the groups feature: the groups the signed-in user belongs
/// to, plus what the entry points on the home screen need to know before
/// creating a group or joining one.
@freezed
abstract class GroupsState with _$GroupsState {
  const GroupsState._();

  const factory GroupsState({
    /// The user's groups, oldest first — exactly what `myGroups` returned.
    @Default(<Group>[]) List<Group> groups,

    /// A `myGroups` request is in flight.
    @Default(false) bool loading,

    /// Whether the list was ever loaded successfully in this session, so an
    /// empty list can be told apart from "not loaded yet".
    @Default(false) bool loaded,

    /// Whether there is a signed-in session. Groups are an authenticated
    /// feature — a guest is offered a sign-in prompt instead of the cards.
    @Default(false) bool authenticated,

    /// Whether the `groups` feature flag is currently on. Nothing is requested
    /// while it is off: the server refuses those calls anyway.
    @Default(false) bool featureEnabled,

    /// The caller's profile, needed to decide whether to ask for a display name
    /// before joining or creating (the server rejects a nameless member).
    UserProfile? profile,

    /// A create/join/leave call is in flight — the buttons stay disabled while
    /// it is.
    @Default(false) bool busy,

    /// The last failure, surfaced once and then cleared.
    String? errorMessage,

    /// A group the user just created or joined: the UI opens it and then clears
    /// this with [GroupOpenHandled].
    String? openGroupId,

    /// What the invite code the user typed leads to. The UI shows it, asks for
    /// confirmation and then clears it with [GroupInvitePreviewHandled].
    GroupInvitePreview? invitePreview,

    /// The code [invitePreview] was read from, so accepting it needs no
    /// re-typing.
    String? previewToken,
  }) = _GroupsState;

  /// Whether the "you have no groups yet" copy should be shown.
  bool get isEmpty => loaded && groups.isEmpty;

  /// Whether a display-name dialog must come first (signed in, profile known,
  /// no name yet). When the profile could not be read this stays `false` and
  /// the server has the last word.
  bool get mustPromptDisplayName =>
      authenticated && profile != null && !profile!.hasDisplayName;

  /// The group with this id, or `null` if the user is not (or no longer) in it.
  Group? byId(String id) {
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }
}
