import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';

/// The screen behind every unknown address (mistyped URL, an outdated deep
/// link, a route removed in a newer build). Unlike routemaster's default
/// not-found page it is designed and, crucially, has a way out — `replace`
/// rebuilds the stack from '/home', so the dead address is gone from history.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.explore_off_outlined,
                      size: 48,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    LocaleKeys.notFound_title.tr(),
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocaleKeys.notFound_message.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    path,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Routemaster.of(context).replace('/home'),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(LocaleKeys.notFound_home.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
