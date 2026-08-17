import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';

import '../../generated/locale_keys.g.dart';

/// What the home screen shows at the top while the app is offline.
///
/// The home content (custom lists, groups) mostly lives on the backend, so
/// instead of a "no network / retry" per block the screen says the app is
/// offline and points at what still works: the question bank and the exam
/// simulation are bundled assets and need no connection. There is no retry —
/// once the connection returns every block reloads on its own.
class OfflineHomeCard extends StatelessWidget {
  const OfflineHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LocaleKeys.network_offlineTitle.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.network_offlineBody.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.quiz_outlined),
                  label: Text(LocaleKeys.network_goToQuestions.tr()),
                  // The tab shell (`IndexedPage` in routes.dart) switches to
                  // the matching tab for a push of one of its root paths.
                  onPressed: () => Routemaster.of(context).push('/questions'),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(LocaleKeys.network_goToExam.tr()),
                  onPressed: () => Routemaster.of(context).push('/practice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
