import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';

/// The one "couldn't load — retry" block for every remote section of the app.
///
/// [message] is the text to show; pass what `describeError` returned so a
/// transport failure reads as "no network" and a server refusal shows the
/// server's own words. `null` falls back to the generic "could not load".
///
/// Two layouts share the copy: the default is a centered block for a screen or
/// a card that has nothing else to show; [compact] is a left-aligned couple of
/// lines for a section that sits inside another scroll view (a question tab,
/// a home-screen block) and must not hijack the page.
class LoadFailedView extends StatelessWidget {
  const LoadFailedView({
    super.key,
    required this.onRetry,
    this.message,
    this.compact = false,
    this.offline = false,
  });

  final VoidCallback onRetry;
  final String? message;
  final bool compact;

  /// Draw the "cloud off" glyph instead of the generic error one.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ?? LocaleKeys.network_loadFailed.tr();
    final icon = offline ? Icons.cloud_off_outlined : Icons.error_outline;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(LocaleKeys.network_retry.tr()),
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh),
              label: Text(LocaleKeys.network_retry.tr()),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
