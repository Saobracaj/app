import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/feature_flags_snapshot.dart';
import '../domain/app_feature.dart';
import '../state_management/feature_flags_bloc.dart';
import '../state_management/feature_flags_events.dart';
import '../state_management/feature_flags_state.dart';

/// Settings screen listing every product feature grouped by access tier.
///
/// Guest features (and any unlocked authenticated/premium one) carry a local
/// on/off toggle stored in shared preferences; locked features show why they
/// are unavailable (sign in / subscription). Premium availability comes from the
/// backend `featureFlags` query.
class FeatureFlagsPage extends StatelessWidget {
  const FeatureFlagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('featureFlags.title'.tr())),
      body: SafeArea(child: ListView(children: const [FeatureFlagsContent()])),
    );
  }
}

/// Список фич без собственного скролла и Scaffold — встраивается и в отдельный
/// экран, и в правую панель настроек на широком экране. [FeatureFlagsBloc]
/// глобальный, поэтому провайдера здесь нет.
class FeatureFlagsContent extends StatelessWidget {
  const FeatureFlagsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureFlagsBloc, FeatureFlagsState>(
      builder: (context, state) {
        final snapshot = state.snapshot;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              'featureFlags.localSection'.tr(),
              'featureFlags.localSectionSubtitle'.tr(),
            ),
            for (final f in _tier(FeatureAccess.guest))
              _FeatureTile(feature: f, snapshot: snapshot),
            const Divider(height: 0),
            _SectionHeader(
              'featureFlags.accountSection'.tr(),
              'featureFlags.accountSectionSubtitle'.tr(),
            ),
            for (final f in _tier(FeatureAccess.authenticated))
              _FeatureTile(feature: f, snapshot: snapshot),
            const Divider(height: 0),
            _SectionHeader(
              'featureFlags.premiumSection'.tr(),
              'featureFlags.premiumSectionSubtitle'.tr(),
            ),
            for (final f in _tier(FeatureAccess.premium))
              if (f != AppFeature.russianContent)
                _FeatureTile(feature: f, snapshot: snapshot),
            const Divider(height: 0),
            _SectionHeader('featureFlags.russianSection'.tr(), null),
            _FeatureTile(
              feature: AppFeature.russianContent,
              snapshot: snapshot,
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  static List<AppFeature> _tier(FeatureAccess access) =>
      AppFeature.values.where((f) => f.access == access).toList();
}

/// One feature row: a switch when the tier is satisfied (bound to the local
/// toggle), or a lock hint explaining what unlocks it.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.snapshot});

  final AppFeature feature;
  final FeatureFlagsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tierSatisfied = switch (feature.access) {
      FeatureAccess.guest => true,
      FeatureAccess.authenticated => snapshot.authenticated,
      FeatureAccess.premium =>
        snapshot.authenticated && snapshot.grants.contains(feature.key),
    };
    final title = tr('featureFlags.features.${feature.key}');

    if (!tierSatisfied) {
      final hint = feature.access == FeatureAccess.premium
          ? 'featureFlags.lockedPremium'.tr()
          : 'featureFlags.lockedAuth'.tr();
      return ListTile(
        enabled: false,
        leading: const Icon(Icons.lock_outline),
        title: Text(title),
        subtitle: Text(hint),
      );
    }

    return SwitchListTile(
      title: Text(title),
      value: snapshot.localEnabled(feature),
      onChanged: (value) =>
          context.read<FeatureFlagsBloc>().add(FeatureToggled(feature, value)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
