import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

/// The authenticated caller's Saobraćaj profile, mirroring the `UserProfile`
/// GraphQL type (`myProfile` / `setDisplayName`) in `saobracaj_backend`.
///
/// [displayName] is the public name shown next to public question comments; it
/// is `null` until the user sets one (and, once set, can never be cleared back
/// to empty — the backend rejects an effectively empty value). [commentBan] is
/// the moderator-controlled flag that blocks the user from writing comments.
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    String? displayName,
    @Default(false) bool commentBan,
  }) = _UserProfile;

  const UserProfile._();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final name = (json['displayName'] as String?)?.trim();
    return UserProfile(
      displayName: (name == null || name.isEmpty) ? null : name,
      commentBan: json['commentBan'] == true,
    );
  }

  /// Whether the user has set a (non-empty) display name.
  bool get hasDisplayName => (displayName ?? '').trim().isNotEmpty;

  /// Whether the user may currently write comments: signed in (implied by having
  /// a profile), not banned, and with a display name set.
  bool get canComment => !commentBan && hasDisplayName;
}
