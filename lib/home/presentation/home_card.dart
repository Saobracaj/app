import 'package:flutter/material.dart';

import '../../core/presentation/wide_layout.dart';
import '../../question_lists/presentation/question_lists_section.dart'
    show kListCardRadius;

/// The container every home-screen card sits in: a title row (icon, title,
/// an optional trailing control) over the card's body.
///
/// On the phone it is a filled tile like the question-list chips
/// (`surfaceContainerHigh`, radius 18); on a wide screen it follows the web
/// mock-up — a `surface` card with an `outlineVariant` border on the darker
/// page canvas, the same as [SurfaceCard].
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.onTap,
    this.wide = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
    return Material(
      color: wide ? scheme.surface : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          wide ? kWideCardRadius : kListCardRadius,
        ),
        side: wide ? BorderSide(color: scheme.outlineVariant) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// A caption line under a figure: `bodySmall` in `onSurfaceVariant`.
class HomeCaption extends StatelessWidget {
  const HomeCaption(this.text, {super.key, this.maxLines = 3});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
