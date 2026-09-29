import 'dart:ui' as ui show TextDirection;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/analytics/analytics_service.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../../test/practice/finalize_practice.dart' show kMinPoints;
import '../../theme/quiz_colors.dart';
import '../domain/home_insights.dart';
import '../state_management/home_insights_bloc.dart';
import '../state_management/home_insights_state.dart';
import 'home_card.dart';

/// «Симуляции экзамена»: the scores of the last simulations as a line with a
/// dot per attempt (green passed, red failed), the pass mark as a dashed
/// line, and «сдано N из последних M» underneath.
class ExamTrendCard extends StatelessWidget {
  const ExamTrendCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeInsightsBloc, HomeInsightsState>(
      builder: (context, state) {
        if (!state.loaded) return const SizedBox.shrink();
        final trend = state.examTrend;
        final theme = Theme.of(context);
        final quiz = theme.quiz;
        return HomeCard(
          wide: wide,
          title: LocaleKeys.homeInsights_examTrend_title.tr(),
          icon: Icons.timeline,
          trailing: TextButton(
            onPressed: () {
              analytics.logHomeCardOpened(
                card: AppFeature.homeExamTrend.key,
                target: 'simulation',
              );
              Routemaster.of(context).push('/practice');
            },
            child: Text(LocaleKeys.homeInsights_examTrend_start.tr()),
          ),
          child: trend == null
              ? HomeCaption(LocaleKeys.homeInsights_examTrend_empty.tr())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 96,
                      child: CustomPaint(
                        painter: ExamTrendPainter(
                          attempts: trend.attempts,
                          passMark: kMinPoints,
                          line: theme.colorScheme.primary,
                          passed: quiz.correct,
                          failed: quiz.wrong,
                          surface: wide
                              ? theme.colorScheme.surface
                              : theme.colorScheme.surfaceContainerHigh,
                          guide: theme.colorScheme.outlineVariant,
                          label: theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          passLabel: LocaleKeys.homeInsights_examTrend_passMark
                              .tr(args: ['$kMinPoints']),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocaleKeys.homeInsights_examTrend_passedOfRecent.tr(
                        args: [
                          '${trend.passedOfRecent}',
                          '${trend.recentWindow}',
                        ],
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    HomeCaption(
                      LocaleKeys.homeInsights_examTrend_last.tr(
                        args: [
                          '${trend.last.points}',
                          '${trend.last.mistakes}',
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

/// One series, one axis (0–100 points), the pass mark as a dashed guide with
/// its label, thin line, 8-px dots ringed with the surface colour, the last
/// value labelled directly.
class ExamTrendPainter extends CustomPainter {
  const ExamTrendPainter({
    required this.attempts,
    required this.passMark,
    required this.line,
    required this.passed,
    required this.failed,
    required this.surface,
    required this.guide,
    required this.label,
    required this.passLabel,
  });

  final List<ExamAttempt> attempts;
  final int passMark;
  final Color line;
  final Color passed;
  final Color failed;
  final Color surface;
  final Color guide;
  final TextStyle label;
  final String passLabel;

  static const _padTop = 12.0;
  static const _padBottom = 6.0;
  static const _padSide = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (attempts.isEmpty) return;
    final plotHeight = size.height - _padTop - _padBottom;
    double y(int points) =>
        _padTop + plotHeight * (1 - points.clamp(0, 100) / 100);
    final n = attempts.length;
    final step = n == 1 ? 0.0 : (size.width - 2 * _padSide) / (n - 1);
    double x(int i) => n == 1 ? size.width / 2 : _padSide + step * i;

    // Pass mark: dashed guide with a small label at its right end.
    final passY = y(passMark);
    final dash = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < size.width; dx += 8) {
      canvas.drawLine(Offset(dx, passY), Offset(dx + 4, passY), dash);
    }
    final passText = TextPainter(
      text: TextSpan(text: passLabel, style: label),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    passText.paint(
      canvas,
      Offset(size.width - passText.width, passY - passText.height - 2),
    );

    // The line.
    if (n > 1) {
      final path = Path()..moveTo(x(0), y(attempts[0].points));
      for (var i = 1; i < n; i++) {
        path.lineTo(x(i), y(attempts[i].points));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Dots: status colour by verdict, a surface ring so they read over the
    // line and each other.
    for (var i = 0; i < n; i++) {
      final center = Offset(x(i), y(attempts[i].points));
      canvas.drawCircle(center, 6, Paint()..color = surface);
      canvas.drawCircle(
        center,
        4,
        Paint()..color = attempts[i].passed ? passed : failed,
      );
    }

    // The last value, labelled directly.
    final last = attempts.last;
    final valueText = TextPainter(
      text: TextSpan(
        text: '${last.points}',
        style: label.copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final lastX = x(n - 1);
    final lastY = y(last.points);
    final above = lastY - valueText.height - 8 >= 0;
    valueText.paint(
      canvas,
      Offset(
        (lastX - valueText.width / 2).clamp(0, size.width - valueText.width),
        above ? lastY - valueText.height - 8 : lastY + 8,
      ),
    );
  }

  @override
  bool shouldRepaint(ExamTrendPainter old) =>
      old.attempts != attempts ||
      old.passMark != passMark ||
      old.line != line ||
      old.passed != passed ||
      old.failed != failed ||
      old.surface != surface ||
      old.guide != guide ||
      old.label != label ||
      old.passLabel != passLabel;
}
