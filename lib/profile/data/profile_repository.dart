import 'package:injectable/injectable.dart';

import '../../auth/data/graphql_client.dart';
import '../models/user_profile.dart';

/// Reads and updates the caller's own Saobraćaj profile (display name +
/// comment-ban flag) via the `myProfile` query and `setDisplayName` mutation in
/// `saobracaj_backend`. Both require an authenticated user.
///
/// Registered for DI via injectable (`@lazySingleton`), mirroring
/// [CommentRepository]; consumed by the Display Name settings screen and by the
/// public-comments flow (which needs to know whether the user may comment).
@lazySingleton
class ProfileRepository {
  ProfileRepository(this._client);

  final GraphqlClient _client;

  static const _myProfileQuery = r'''
    query MyProfile {
      myProfile { displayName commentBan }
    }
  ''';

  static const _setDisplayNameMutation = r'''
    mutation SetDisplayName($displayName: String!) {
      setDisplayName(displayName: $displayName) { displayName commentBan }
    }
  ''';

  /// The caller's profile. Requires a signed-in session.
  Future<UserProfile> myProfile() async {
    final data = await _client.run(_myProfileQuery, authenticated: true);
    final profile = data['myProfile'];
    if (profile is! Map) return const UserProfile();
    return UserProfile.fromJson(profile.cast<String, dynamic>());
  }

  /// Set the caller's public display name (trimmed + validated server-side).
  /// Throws [GraphqlException] on a validation or network error.
  Future<UserProfile> setDisplayName(String displayName) async {
    final data = await _client.run(
      _setDisplayNameMutation,
      variables: {'displayName': displayName},
      authenticated: true,
    );
    final profile = data['setDisplayName'];
    if (profile is! Map) return const UserProfile();
    return UserProfile.fromJson(profile.cast<String, dynamic>());
  }
}
