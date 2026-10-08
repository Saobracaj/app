import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/analytics/analytics_service.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../../test/practice/finalize_practice.dart' show kMinPoints;
import '../../test/start_test.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Готовность к экзамену»: a ring with the share of expected exam points the
/// user currently knows, a tick at the pass mark, and a button leading to the
/// subcategory that loses the most points.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        final readiness = state.readiness;
        if (!state.loaded || readiness == null) return const SizedBox.shrink();
        final weakest = state.weakestTopic;
        final theme = Theme.of(context);
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_readiness_title.tr(),
          icon: Icons.speed,
          trailing: IconButton(
            tooltip: LocaleKeys.homeInsights_readiness_hint.tr(
              args: ['$kMinPoints'],
            ),
            icon: const Icon(Icons.help_outline, size: 20),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(LocaleKeys.homeInsights_readiness_title.tr()),
                content: Text(
                  LocaleKeys.homeInsights_readiness_hint.tr(
                    args: ['$kMinPoints'],
                  ),
                ),
              ),
            ),
          ),
          child: readiness.answered == 0
              ? HomeCaption(LocaleKeys.homeInsights_readiness_empty.tr())
              : Row(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CustomPaint(
                        painter: ReadinessRingPainter(
                          share: readiness.share,
                          passShare: kMinPoints / 100,
                          track: theme.colorScheme.surfaceContainerHighest,
                          progress: theme.colorScheme.primary,
                          tick: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: Center(
                          child: Text(
                            '${readiness.percent}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeCaption(
                            LocaleKeys.homeInsights_readiness_known.tr(
                              args: [
                                '${readiness.known}',
                                '${readiness.total}',
                              ],
                            ),
                          ),
                          if (weakest != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.tonal(
                                onPressed: () {
                                  analytics.logHomeCardOpened(
                                    card: AppFeature.homeReadiness.key,
                                    target: 'practice',
                                  );
                                  openStartTest(
                                    context,
                                    weakest.questionIds,
                                    subcategory: '${weakest.subcategoryId}',
                                  );
                                },
                                child: Text(
                                  LocaleKeys
                                      .homeInsights_readiness_practiceWeakest
                                      .tr(),
                                ),
                              ),
                            ),
                          ],
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

/// The readiness ring: a full track, the covered arc from 12 o'clock and a
/// short tick across the ring at the pass mark.
class ReadinessRingPainter extends CustomPainter {
  const ReadinessRingPainter({
    required this.share,
    required this.passShare,
    required this.track,
    required this.progress,
    required this.tick,
  });

  final double share;
  final double passShare;
  final Color track;
  final Color progress;
  final Color tick;

  static const _stroke = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - _stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = track);
    const start = -math.pi / 2;
    if (share > 0) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * share.clamp(0, 1),
        false,
        paint..color = progress,
      );
    }
    final angle = start + 2 * math.pi * passShare;
    final direction = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      center + direction * (radius - _stroke / 2 - 2),
      center + direction * (radius + _stroke / 2 + 2),
      Paint()
        ..color = tick
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(ReadinessRingPainter old) =>
      old.share != share ||
      old.passShare != passShare ||
      old.track != track ||
      old.progress != progress ||
      old.tick != tick;
}
