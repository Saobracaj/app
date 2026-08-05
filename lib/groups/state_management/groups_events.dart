import '../models/group.dart';

/// User actions and internal signals of [GroupsBloc].
sealed class GroupsEvent {
  const GroupsEvent();
}

/// Subscribe to the repository and load the list once, from `main()`.
class GroupsStarted extends GroupsEvent {
  const GroupsStarted();
}

/// Pull `myGroups` again — pull-to-refresh, and after returning from a group
/// screen.
class GroupsRefreshed extends GroupsEvent {
  const GroupsRefreshed();
}

/// The repository published a new list (internal).
class GroupsUpdated extends GroupsEvent {
  const GroupsUpdated(this.groups);

  final List<Group> groups;
}

/// The session changed (internal): reload on sign-in, drop everything on
/// sign-out.
class GroupsSessionChanged extends GroupsEvent {
  const GroupsSessionChanged({required this.authenticated});

  final bool authenticated;
}

/// The `groups` feature flag flipped (internal). It can arrive after the
/// session does — the flags are refreshed asynchronously on login — so the list
/// waits for it rather than asking the backend for something it is not allowed
/// to read yet.
class GroupsAvailabilityChanged extends GroupsEvent {
  const GroupsAvailabilityChanged({required this.enabled});

  final bool enabled;
}

/// Create a group. [displayNameToSet] carries the name the user typed in the
/// display-name dialog, when one was needed.
class GroupCreationRequested extends GroupsEvent {
  const GroupCreationRequested(this.name, {this.displayNameToSet});

  final String name;
  final String? displayNameToSet;
}

/// Look up what an invite code leads to, before committing to it. The answer
/// arrives in the state and the UI asks the user to confirm.
class GroupInvitePreviewRequested extends GroupsEvent {
  const GroupInvitePreviewRequested(this.token);

  final String token;
}

/// The preview was shown (and accepted or dismissed); clear it.
class GroupInvitePreviewHandled extends GroupsEvent {
  const GroupInvitePreviewHandled();
}

/// Join a group with an invite code (case-insensitive, dashes optional).
class GroupJoinRequested extends GroupsEvent {
  const GroupJoinRequested(this.token, {this.displayNameToSet});

  final String token;
  final String? displayNameToSet;
}

/// Leave a group — every member but the owner may.
class GroupLeaveRequested extends GroupsEvent {
  const GroupLeaveRequested(this.groupId);

  final String groupId;
}

/// The error message was shown; clear it.
class GroupsErrorShown extends GroupsEvent {
  const GroupsErrorShown();
}

/// The freshly created/joined group was opened; clear the pending navigation.
class GroupOpenHandled extends GroupsEvent {
  const GroupOpenHandled();
}
