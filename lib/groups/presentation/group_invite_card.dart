import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../generated/locale_keys.g.dart';
import '../state_management/group_bloc.dart';
import '../state_management/group_events.dart';
import '../state_management/group_state.dart';
import 'group_page.dart' show copyAndTell;

/// How the owner invites people: the code, the link built from it, and a QR of
/// that link.
///
/// The code is always shown, never only the QR or only the link — the web route
/// behind the link is not deployed yet, so reading the code out or typing it in
/// has to stay possible. Only one invite is active at a time: issuing a new one
/// revokes the previous, which is what "the code leaked" needs.
class GroupInviteCard extends StatelessWidget {
  const GroupInviteCard({super.key, required this.state});

  final GroupState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = state.invite;
    final live = state.inviteIsLive;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.groups_invite_title.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.groups_invite_description.tr(),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (invite == null)
              Text(
                LocaleKeys.groups_invite_none.tr(),
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              if (live)
                Center(
                  child: QrImageView(
                    data: invite.link,
                    size: 180,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              if (live)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      LocaleKeys.groups_invite_qrHint.tr(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SelectableText(
                invite.token,
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(invite.link, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                live
                    ? LocaleKeys.groups_invite_expires.tr(
                        args: [_formatDate(context, invite.expiresAt)],
                      )
                    : LocaleKeys.groups_invite_expired.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: live
                      ? theme.colorScheme.outline
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => copyAndTell(context, invite.token),
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(LocaleKeys.groups_invite_code.tr()),
                  ),
                  TextButton.icon(
                    onPressed: () => copyAndTell(context, invite.link),
                    icon: const Icon(Icons.link_outlined),
                    label: Text(LocaleKeys.groups_invite_link.tr()),
                  ),
                  TextButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(text: invite.link),
                    ),
                    icon: const Icon(Icons.ios_share_outlined),
                    label: Text(LocaleKeys.groups_invite_share.tr()),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: state.busy
                      ? null
                      : () => context.read<GroupBloc>().add(
                          const GroupInviteRegenerated(),
                        ),
                  child: Text(
                    invite == null
                        ? LocaleKeys.groups_invite_create.tr()
                        : LocaleKeys.groups_invite_regenerate.tr(),
                  ),
                ),
                if (invite != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => context.read<GroupBloc>().add(
                            const GroupInviteRevoked(),
                          ),
                    child: Text(LocaleKeys.groups_invite_revoke.tr()),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) return '';
    return DateFormat.yMMMd(context.locale.languageCode).add_Hm().format(date);
  }
}
