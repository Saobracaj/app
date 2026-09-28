import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/analytics/analytics_service.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Продолжить конспект»: the category whose konspekt was opened last, one
/// tap away. Hidden until a konspekt has been opened on this device.
class ContinueKonspektCard extends StatelessWidget {
  const ContinueKonspektCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        final konspekt = state.lastKonspekt;
        if (!state.loaded || konspekt == null) return const SizedBox.shrink();
        void open() {
          analytics.logHomeCardOpened(
            card: AppFeature.homeContinueKonspekt.key,
            target: 'konspekt',
          );
          Routemaster.of(context).push(
            '/konspekt',
            queryParameters: {'category': konspekt.categoryId},
          );
        }

        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_konspekt_title.tr(),
          icon: Icons.menu_book_outlined,
          onTap: open,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  konspekt.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: open,
                child: Text(LocaleKeys.homeInsights_konspekt_continue.tr()),
              ),
            ],
          ),
        );
      },
    );
  }
}
