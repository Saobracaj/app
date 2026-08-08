import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';

/// The "РУ" toggle used in app bars: outlined while off, filled with primary
/// while on. One widget so the question screen and the law screen show the
/// same control; the backing state differs per screen, hence the callbacks.
class TranslationChip extends StatelessWidget {
  const TranslationChip({super.key, required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: on ? scheme.primary : null,
            border: on
                ? null
                : Border.all(color: scheme.onSurfaceVariant, width: 1.5),
          ),
          child: Text(
            LocaleKeys.quest_ruToggle.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
