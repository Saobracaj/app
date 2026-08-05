/// User actions on one group's screen.
sealed class GroupEditEvent {
  const GroupEditEvent();
}

/// Load the group (roster, bans, invite, recent activity).
class GroupOpened extends GroupEditEvent {
  const GroupOpened();
}

/// Rename the group. Owner only.
class GroupRenamed extends GroupEditEvent {
  const GroupRenamed(this.name);

  final String name;
}

/// Delete the group. Owner only, and only once everybody else has left.
class GroupDeleted extends GroupEditEvent {
  const GroupDeleted();
}

/// Remove somebody from the group; they are banned at the same time so the
/// invite they still hold stops working for them.
class GroupMemberRemoved extends GroupEditEvent {
  const GroupMemberRemoved(this.userId);

  final String userId;
}

/// Lift a ban, letting the person accept an invite again.
class GroupMemberUnbanned extends GroupEditEvent {
  const GroupMemberUnbanned(this.userId);

  final String userId;
}

/// Hand the group over to another member.
class GroupOwnershipTransferred extends GroupEditEvent {
  const GroupOwnershipTransferred(this.userId);

  final String userId;
}

/// Issue a fresh invite code, revoking the previous one.
class GroupInviteRegenerated extends GroupEditEvent {
  const GroupInviteRegenerated();
}

/// Withdraw the current invite without issuing a replacement.
class GroupInviteRevoked extends GroupEditEvent {
  const GroupInviteRevoked();
}

/// The error message was shown; clear it.
class GroupErrorShown extends GroupEditEvent {
  const GroupErrorShown();
}
