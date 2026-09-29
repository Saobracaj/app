import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/analytics/analytics_service.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../feature_flags/state_management/feature_flags_bloc.dart';
import '../../generated/locale_keys.g.dart';
import '../../zakon/presentation/road_sign_viewer.dart';
import '../state_management/daily_sign_bloc.dart';
import '../state_management/daily_sign_events.dart';
import '../state_management/daily_sign_state.dart';
import 'home_card.dart';

/// «Знак дня»: a flashcard — the sign, its name hidden until asked, and a
/// link to the viewer with the pravilnik description.
class DailySignCard extends StatelessWidget {
  const DailySignCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DailySignBloc, DailySignState>(
      builder: (context, state) {
        final sign = state.sign;
        if (sign == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final russian = context.select<FeatureFlagsBloc, bool>(
          (b) => b.state.russianContent,
        );
        final name = russian ? sign.nameRu ?? sign.nameSr : sign.nameSr;
        // The viewer takes the file name («ii-2»), not the asset path.
        final file = sign.asset
            .split('/')
            .last
            .replaceAll(RegExp(r'\.svg$'), '');
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_dailySign_title.tr(),
          icon: Icons.signpost_outlined,
          child: Row(
            children: [
              Container(
                width: 88,
                height: 88,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(sign.asset, fit: BoxFit.contain),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.revealed) ...[
                      Text(
                        name ?? sign.code,
                        style: theme.textTheme.titleMedium,
                      ),
                      HomeCaption(sign.code, maxLines: 1),
                    ] else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          key: const ValueKey('daily_sign_reveal'),
                          onPressed: () => context.read<DailySignBloc>().add(
                            DailySignRevealed(),
                          ),
                          child: Text(
                            LocaleKeys.homeInsights_dailySign_reveal.tr(),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          analytics.logHomeCardOpened(
                            card: AppFeature.homeDailySign.key,
                            target: 'sign',
                          );
                          showRoadSignViewer(
                            context,
                            sign: file,
                            documentCode: sign.code,
                          );
                        },
                        child: Text(
                          LocaleKeys.homeInsights_dailySign_open.tr(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
