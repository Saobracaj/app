import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/invite_code.dart';
import 'group_event.dart';

part 'group.freezed.dart';

/// A group as seen by one of its members, mirroring the `Group` GraphQL type in
/// `saobracaj_backend`.
///
/// The roster, the ban list and the invite code are resolved lazily on the
/// server, so a query that only wants the home-screen cards leaves them out and
/// they stay empty here. [feedPreview] holds the few latest events the card
/// shows without opening the feed.
@freezed
abstract class Group with _$Group {
  const factory Group({
    @Default('') String id,
    @Default('') String name,
    @Default('') String ownerId,
    DateTime? createdAt,

    /// How many people are in the group right now, owner included.
    @Default(0) int memberCount,

    /// Whether the caller owns this group — the owner-only actions (rename,
    /// remove, transfer, delete) hang off this.
    @Default(false) bool viewerIsOwner,
    @Default(<GroupMember>[]) List<GroupMember> members,

    /// The people the owner removed; empty for everybody but the owner.
    @Default(<GroupBan>[]) List<GroupBan> bannedMembers,

    /// The code currently handing out membership; owner-only, `null` when there
    /// is none or it expired.
    GroupInvite? invite,

    /// The last few feed entries, for the group card on the home screen.
    @Default(<GroupEvent>[]) List<GroupEvent> feedPreview,
  }) = _Group;

  const Group._();

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? '',
      )?.toLocal(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      viewerIsOwner: json['viewerIsOwner'] == true,
      members: _list(json['members'], GroupMember.fromJson),
      bannedMembers: _list(json['bannedMembers'], GroupBan.fromJson),
      invite: json['invite'] is Map
          ? GroupInvite.fromJson(
              (json['invite'] as Map).cast<String, dynamic>(),
            )
          : null,
      // Events this build cannot render are dropped here rather than in every
      // widget that walks the list.
      feedPreview: _list(
        json['feedPreview'],
        GroupEvent.fromJson,
      ).where((e) => e.isRenderable).toList(),
    );
  }

  /// Whether the caller may leave: everybody but the owner, who has to hand the
  /// group over first (the server enforces the same rule).
  bool get viewerCanLeave => !viewerIsOwner;

  /// Whether the owner may delete the group now — only once they are the last
  /// one standing.
  bool get canBeDeleted => viewerIsOwner && memberCount <= 1;
}

/// One member of a group.
@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    @Default('') String userId,
    @Default('') String displayName,
    DateTime? joinedAt,
    @Default(false) bool isOwner,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      joinedAt: DateTime.tryParse(
        json['joinedAt']?.toString() ?? '',
      )?.toLocal(),
      isOwner: json['isOwner'] == true,
    );
  }
}

/// Somebody the owner removed from the group. They cannot come back through any
/// invite until the owner lifts the ban.
@freezed
abstract class GroupBan with _$GroupBan {
  const factory GroupBan({
    @Default('') String userId,
    @Default('') String displayName,
    DateTime? bannedAt,
  }) = _GroupBan;

  factory GroupBan.fromJson(Map<String, dynamic> json) {
    return GroupBan(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      bannedAt: DateTime.tryParse(
        json['bannedAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// A group's current invite code. One is active per group at a time.
@freezed
abstract class GroupInvite with _$GroupInvite {
  const factory GroupInvite({
    /// The code in canonical form, `ABC-DEF-GHI`.
    @Default('') String token,
    @Default('') String groupId,
    DateTime? createdAt,

    /// When the code stops working — a week after it was issued.
    DateTime? expiresAt,
  }) = _GroupInvite;

  const GroupInvite._();

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    return GroupInvite(
      token: json['token']?.toString() ?? '',
      groupId: json['groupId']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? '',
      )?.toLocal(),
      expiresAt: DateTime.tryParse(
        json['expiresAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }

  /// The link the owner shares. The web route does not exist yet (it comes with
  /// the deep-link task), which is why the code itself is always shown too.
  String get link => '$kInviteLinkBase$token';
}

/// What somebody holding an invite code sees *before* joining.
@freezed
abstract class GroupInvitePreview with _$GroupInvitePreview {
  const factory GroupInvitePreview({
    @Default('') String groupId,
    @Default('') String name,
    @Default(0) int memberCount,

    /// Whether the viewer is already in this group — the client then just opens
    /// it instead of offering to join again.
    @Default(false) bool alreadyMember,
  }) = _GroupInvitePreview;

  factory GroupInvitePreview.fromJson(Map<String, dynamic> json) {
    return GroupInvitePreview(
      groupId: json['groupId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      alreadyMember: json['alreadyMember'] == true,
    );
  }
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    raw is List
    ? raw.whereType<Map>().map((e) => parse(e.cast<String, dynamic>())).toList()
    : const [];
