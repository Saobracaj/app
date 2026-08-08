import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../../auth/data/graphql_subscription_client.dart';
import '../models/group.dart';
import '../models/group_event.dart';
import '../models/group_feed_page.dart';
import '../models/group_feed_update.dart';

/// Everything the client knows about the user's groups, straight from
/// `saobracaj_backend` (the `groups` module).
///
/// Groups are not cached on the device: unlike question lists they are shared
/// state — a member joins, a name changes, the feed grows — and a stale card
/// would be worse than an empty one. What the repository does keep is the last
/// answer to `myGroups`, published on [changes], so the home-screen cards and
/// the group screen render the same list and update together.
///
/// The invariants (owner cannot leave, 30 members, 5 memberships, bans) live on
/// the server; this class only carries the calls and surfaces the server's
/// error message.
@lazySingleton
class GroupsRepository {
  GroupsRepository(this._client, this._subscriptions);

  final GraphqlClient _client;
  final GraphqlSubscriptionClient _subscriptions;

  /// The scalar fields of a group. `members` / `bannedMembers` / `invite` are
  /// resolved lazily by the server, so they are only asked for on the group
  /// screen.
  static const _groupFields =
      'id name ownerId createdAt memberCount viewerIsOwner';

  static const _memberFields = 'userId displayName joinedAt isOwner';

  static const _eventFields = '''
    id kind occurredAt
    actor { id displayName }
    target { id displayName }
    subcategory {
      subcategory rightAnswers allAnswers delta
      previousRightAnswers previousAllAnswers
    }
    practice { points mistakes passed durationSeconds wrongAnswers }
    achievement { achievement streak subcategory }
    rename { name previousName }
  ''';

  static const _inviteFields = 'token groupId createdAt expiresAt';

  final StreamController<List<Group>> _controller =
      StreamController<List<Group>>.broadcast();

  List<Group> _groups = const [];

  /// The caller's groups, replayed to each new listener followed by every
  /// subsequent change.
  Stream<List<Group>> get changes async* {
    yield _groups;
    yield* _controller.stream;
  }

  /// The latest known list (synchronous read).
  List<Group> get groups => _groups;

  /// Pull the caller's groups (with the card's feed preview) and publish them.
  /// Errors reach the caller — the home section shows a retry rather than an
  /// empty list that looks like "you have no groups".
  Future<List<Group>> refresh() async {
    final data = await _client.run('''
        query MyGroups {
          myGroups { $_groupFields feedPreview { $_eventFields } }
        }
      ''', authenticated: true);
    final raw = data['myGroups'];
    final groups = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => Group.fromJson(e.cast<String, dynamic>()))
              .toList()
        : <Group>[];
    _publish(groups);
    return _groups;
  }

  /// Forget everything when the session ends: a group belongs to a user.
  void onLoggedOut() => _publish(const []);

  /// One group with its roster, the owner's ban list and invite code, and the
  /// feed preview. `null` when it does not exist or the caller is not in it.
  Future<Group?> load(String id) async {
    final data = await _client.run(
      '''
        query GroupDetails(\$id: ID!) {
          group(id: \$id) {
            $_groupFields
            members { $_memberFields }
            bannedMembers { userId displayName bannedAt }
            invite { $_inviteFields }
            feedPreview { $_eventFields }
          }
        }
      ''',
      variables: {'id': id},
      authenticated: true,
    );
    final raw = data['group'];
    if (raw is! Map) return null;
    final group = Group.fromJson(raw.cast<String, dynamic>());
    _merge(group);
    return group;
  }

  /// Create a group; the caller becomes its owner and first member. Requires a
  /// display name (the server refuses without one).
  Future<Group> create(String name) async {
    final group = await _mutateGroup(
      '''
        mutation CreateGroup(\$name: String!) {
          createGroup(name: \$name) { $_groupFields }
        }
      ''',
      {'name': name},
      'createGroup',
    );
    _publish([..._groups, group]);
    return group;
  }

  /// Rename a group. Owner only.
  Future<Group> rename(String id, String name) async {
    final group = await _mutateGroup(
      '''
        mutation RenameGroup(\$id: ID!, \$name: String!) {
          renameGroup(id: \$id, name: \$name) { $_groupFields }
        }
      ''',
      {'id': id, 'name': name},
      'renameGroup',
    );
    _merge(group);
    return group;
  }

  /// Delete a group. Owner only, and only once every other member has left.
  Future<void> delete(String id) async {
    await _client.run(
      r'mutation DeleteGroup($id: ID!) { deleteGroup(id: $id) }',
      variables: {'id': id},
      authenticated: true,
    );
    _publish(_groups.where((g) => g.id != id).toList());
  }

  /// Issue a fresh invite code and revoke whatever was active before — this is
  /// both "invite people" and "regenerate, the old code leaked". Owner only.
  Future<GroupInvite> createInvite(String groupId) async {
    final data = await _client.run(
      '''
        mutation CreateGroupInvite(\$groupId: ID!) {
          createGroupInvite(groupId: \$groupId) { $_inviteFields }
        }
      ''',
      variables: {'groupId': groupId},
      authenticated: true,
    );
    final raw = data['createGroupInvite'];
    if (raw is! Map) throw GraphqlException('Empty server response');
    return GroupInvite.fromJson(raw.cast<String, dynamic>());
  }

  /// Withdraw an invite code without issuing a replacement. Owner only.
  Future<void> revokeInvite(String token) async {
    await _client.run(
      r'mutation RevokeGroupInvite($token: String!) { revokeGroupInvite(token: $token) }',
      variables: {'token': token},
      authenticated: true,
    );
  }

  /// What a code leads to, before the user commits to joining it.
  Future<GroupInvitePreview> invitePreview(String token) async {
    final data = await _client.run(
      r'''
        query GroupInvitePreview($token: String!) {
          groupInvitePreview(token: $token) {
            groupId name memberCount alreadyMember
          }
        }
      ''',
      variables: {'token': token},
      authenticated: true,
    );
    final raw = data['groupInvitePreview'];
    if (raw is! Map) throw GraphqlException('Empty server response');
    return GroupInvitePreview.fromJson(raw.cast<String, dynamic>());
  }

  /// Join a group with an invite code — the only way into a group.
  Future<Group> joinByInvite(String token) async {
    final group = await _mutateGroup(
      '''
        mutation JoinGroupByInvite(\$token: String!) {
          joinGroupByInvite(token: \$token) { $_groupFields }
        }
      ''',
      {'token': token},
      'joinGroupByInvite',
    );
    // Joining a group the caller is already in simply returns it, so merge
    // rather than append.
    _merge(group, insertIfMissing: true);
    return group;
  }

  /// Remove a member. Owner only; the person is banned from the group at the
  /// same time, so they cannot walk back in with the invite they still have.
  Future<void> removeMember(String groupId, String userId) async {
    await _client.run(
      r'''
        mutation RemoveGroupMember($groupId: ID!, $userId: ID!) {
          removeGroupMember(groupId: $groupId, userId: $userId)
        }
      ''',
      variables: {'groupId': groupId, 'userId': userId},
      authenticated: true,
    );
  }

  /// Lift a ban, letting the person accept an invite again. Owner only.
  Future<void> unbanMember(String groupId, String userId) async {
    await _client.run(
      r'''
        mutation UnbanGroupMember($groupId: ID!, $userId: ID!) {
          unbanGroupMember(groupId: $groupId, userId: $userId)
        }
      ''',
      variables: {'groupId': groupId, 'userId': userId},
      authenticated: true,
    );
  }

  /// Leave a group. The owner has to transfer ownership first.
  Future<void> leave(String groupId) async {
    await _client.run(
      r'mutation LeaveGroup($groupId: ID!) { leaveGroup(groupId: $groupId) }',
      variables: {'groupId': groupId},
      authenticated: true,
    );
    _publish(_groups.where((g) => g.id != groupId).toList());
  }

  /// Hand the group over to another member — the only way for an owner to
  /// eventually leave it.
  Future<Group> transferOwnership(String groupId, String userId) async {
    final group = await _mutateGroup(
      '''
        mutation TransferGroupOwnership(\$groupId: ID!, \$userId: ID!) {
          transferGroupOwnership(groupId: \$groupId, userId: \$userId) {
            $_groupFields
          }
        }
      ''',
      {'groupId': groupId, 'userId': userId},
      'transferGroupOwnership',
    );
    _merge(group);
    return group;
  }

  /// One page of a group's feed, newest first. Pass the previous page's
  /// [before]/[beforeId] back in to get the next one.
  Future<GroupFeedPage> feed(
    String groupId, {
    int? limit,
    DateTime? before,
    String? beforeId,
  }) async {
    final data = await _client.run(
      '''
        query GroupFeed(
          \$groupId: ID!, \$limit: Int, \$before: DateTime, \$beforeId: ID
        ) {
          groupFeed(
            groupId: \$groupId, limit: \$limit, before: \$before, beforeId: \$beforeId
          ) {
            events { $_eventFields }
            hasMore nextBefore nextBeforeId
          }
        }
      ''',
      variables: {
        'groupId': groupId,
        'limit': limit,
        'before': before?.toUtc().toIso8601String(),
        'beforeId': beforeId,
      },
      authenticated: true,
    );
    final raw = data['groupFeed'];
    if (raw is! Map) return const GroupFeedPage();
    return GroupFeedPage.fromJson(raw.cast<String, dynamic>());
  }

  /// The group's feed as it grows, over the websocket.
  ///
  /// Only events that happen *while the stream is open* arrive here — the first
  /// page still comes from [feed]. After a dropped connection the server has no
  /// backlog to replay, which is why a reconnect surfaces as
  /// [GroupFeedResumed]: the reader re-reads the head and closes the gap itself.
  Stream<GroupFeedUpdate> feedChanges(String groupId) {
    return _subscriptions
        .subscribe(
          '''
        subscription GroupFeedChanged(\$groupId: ID!) {
          groupFeedChanged(groupId: \$groupId) { $_eventFields }
        }
      ''',
          variables: {'groupId': groupId},
        )
        .map<GroupFeedUpdate?>((message) {
          switch (message) {
            case GraphqlSubscriptionResumed(:final firstConnect):
              return GroupFeedResumed(firstConnect: firstConnect);
            case GraphqlSubscriptionInterrupted():
              return const GroupFeedInterrupted();
            case GraphqlSubscriptionData(:final data):
              final raw = data['groupFeedChanged'];
              if (raw is! Map) return null;
              return GroupFeedEventReceived(
                GroupEvent.fromJson(raw.cast<String, dynamic>()),
              );
          }
        })
        .where((update) => update != null)
        .cast<GroupFeedUpdate>();
  }

  /// Run a mutation that answers with a group and parse it.
  Future<Group> _mutateGroup(
    String mutation,
    Map<String, dynamic> variables,
    String field,
  ) async {
    final data = await _client.run(
      mutation,
      variables: variables,
      authenticated: true,
    );
    final raw = data[field];
    if (raw is! Map) throw GraphqlException('Empty server response');
    return Group.fromJson(raw.cast<String, dynamic>());
  }

  /// Fold a freshly-read group into the published list, keeping the parts the
  /// answer did not carry (a mutation returns the scalar fields only, so the
  /// card's feed preview must not be wiped by a rename).
  void _merge(Group group, {bool insertIfMissing = false}) {
    var found = false;
    final merged = _groups.map((g) {
      if (g.id != group.id) return g;
      found = true;
      return group.copyWith(
        members: group.members.isEmpty ? g.members : group.members,
        bannedMembers: group.bannedMembers.isEmpty
            ? g.bannedMembers
            : group.bannedMembers,
        invite: group.invite ?? g.invite,
        feedPreview: group.feedPreview.isEmpty
            ? g.feedPreview
            : group.feedPreview,
      );
    }).toList();
    if (!found && !insertIfMissing) return;
    _publish(found ? merged : [...merged, group]);
  }

  void _publish(List<Group> groups) {
    _groups = List.unmodifiable(groups);
    _controller.add(_groups);
  }
}
