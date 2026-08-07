import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../domain/app_feature.dart';
import '../state_management/feature_flags_bloc.dart';
import '../state_management/feature_flags_events.dart';

/// Asks once, on the first launch that reaches this build, whether the user
/// wants the Russian-language extras ([AppFeature.russianContent]).
///
/// Only shown when the device language is not Russian and no answer is stored
/// yet — `FeatureFlagsRepository.shouldAskRussianContent` decides, and the
/// answer (either way) is persisted, so the question never comes back. Until it
/// is answered the feature stays off, whatever the backend granted.
///
/// The dialog is drawn *inside* the widget tree rather than pushed with
/// `showDialog`: this sits in `MaterialApp.router`'s `builder`, above the
/// router's own `Navigator`, so there is no route stack to push onto — and
/// rendering it from bloc state keeps the widget stateless.
class RussianContentPrompt extends StatelessWidget {
  const RussianContentPrompt({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shouldAsk = context.select(
      (FeatureFlagsBloc bloc) => bloc.state.snapshot.shouldAskRussianContent,
    );
    if (!shouldAsk) return child;
    return Stack(
      children: [
        child,
        // Same scrim the framework puts under a modal route, so the dialog
        // reads as one even without a route behind it.
        const ModalBarrier(dismissible: false, color: Colors.black54),
        const _RussianContentDialog(),
      ],
    );
  }
}

class _RussianContentDialog extends StatelessWidget {
  const _RussianContentDialog();

  void _answer(BuildContext context, bool enabled) => context
      .read<FeatureFlagsBloc>()
      .add(FeatureToggled(AppFeature.russianContent, enabled));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.translate),
      title: Text(LocaleKeys.featureFlags_russianPrompt_title.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LocaleKeys.featureFlags_russianPrompt_message.tr()),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.featureFlags_russianPrompt_hint.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _answer(context, false),
          child: Text(LocaleKeys.featureFlags_russianPrompt_decline.tr()),
        ),
        FilledButton(
          onPressed: () => _answer(context, true),
          child: Text(LocaleKeys.featureFlags_russianPrompt_accept.tr()),
        ),
      ],
    );
  }
}
