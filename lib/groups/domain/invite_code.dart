/// Group invite codes and the client-side limits that mirror the backend.
///
/// The code is `ABC-DEF-GHI`: nine characters from a 32-letter alphabet with
/// the lookalikes (`0`/`O`, `1`/`I`) removed. The canonical form — upper case,
/// with dashes — is what the server stores and what the invite link carries.
/// The client normalizes what the user typed before sending it, so a code
/// pasted out of a chat message in lower case or without dashes just works, and
/// an obviously wrong one is reported inline instead of as "no such invite".
library;

/// The invite alphabet, identical to `INVITE_ALPHABET` in the backend.
const String kInviteAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

/// How many characters an invite code carries, dashes excluded.
const int kInviteCodeLen = 9;

/// How many characters go between two dashes.
const int kInviteChunkLen = 3;

/// The longest group name the backend accepts (`GROUP_NAME_MAX_LEN`).
const int kGroupNameMaxLen = 40;

/// The base of an invite link. The web route behind it is not deployed yet, so
/// the UI always shows the code itself as well.
const String kInviteLinkBase = 'https://saobracaj.gleb.at/invite/';

/// Bring user input to the canonical `ABC-DEF-GHI` form, or `null` when it
/// cannot be a code at all (wrong length, or a character outside the alphabet —
/// the `O` somebody typed for a zero).
String? normalizeInviteCode(String raw) {
  final code = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (code.length != kInviteCodeLen) return null;
  if (!code.split('').every(kInviteAlphabet.contains)) return null;
  final chunks = <String>[
    for (var i = 0; i < code.length; i += kInviteChunkLen)
      code.substring(i, i + kInviteChunkLen),
  ];
  return chunks.join('-');
}

/// The code lifted out of an invite link, or `null` when the link is not one.
/// Used by the `/invite/:token` route and by pasted links.
String? inviteCodeFromLink(String raw) {
  final trimmed = raw.trim();
  final index = trimmed.lastIndexOf('/');
  return normalizeInviteCode(
    index >= 0 ? trimmed.substring(index + 1) : trimmed,
  );
}
