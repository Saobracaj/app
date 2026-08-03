import 'package:flutter/material.dart';
import 'package:saobracaj/dictionary/dictionary.dart';
import 'package:saobracaj/models/models.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

import 'quest_markdown.dart';

/// One answer choice as a bordered card. Meaning is carried by color and the
/// ✓/✕ marker alone — no "тачно/нетачно" words. After the reveal, correct
/// choices and the wrong ones the user actually picked are highlighted;
/// unpicked wrong choices stay neutral.
class AnswerOptionCard extends StatelessWidget {
  const AnswerOptionCard({
    super.key,
    required this.choice,
    required this.selected,
    required this.revealed,
    required this.showTranslation,
    this.onTap,
  });

  final Choice choice;
  final bool selected;
  final bool revealed;
  final bool showTranslation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quiz = theme.quiz;

    final Color border;
    final Color background;
    Color? foreground;
    Widget? marker;

    if (revealed && choice.isCorrect) {
      border = quiz.correct;
      background = quiz.correctContainer;
      foreground = quiz.onCorrectContainer;
      marker = _Marker(
        color: quiz.correct,
        icon: Icon(Icons.check, size: 14, color: quiz.onCorrect),
      );
    } else if (revealed && selected && !choice.isCorrect) {
      border = quiz.wrong;
      background = quiz.wrongContainer;
      foreground = quiz.onWrongContainer;
      marker = _Marker(
        color: quiz.wrong,
        icon: Icon(Icons.close, size: 14, color: quiz.onWrong),
      );
    } else if (!revealed && selected) {
      border = scheme.primary;
      background = scheme.surfaceContainerHigh;
      marker = _Marker(color: scheme.primary);
    } else {
      border = scheme.outlineVariant;
      background = scheme.surfaceContainerLow;
      marker = _Marker(
        outline: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.5),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: marker),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuestMarkdown(
                        text: choice.text.trim().dict,
                        pStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (showTranslation && choice.translationRu != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            choice.translationRu!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (foreground ?? scheme.onSurface)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 20×20 rounded-square selection marker: outlined while idle, filled with
/// the state color (optionally holding a ✓/✕) otherwise.
class _Marker extends StatelessWidget {
  const _Marker({this.color, this.outline, this.icon});

  final Color? color;
  final Color? outline;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: outline == null
            ? null
            : Border.all(color: outline!, width: 1.5),
      ),
      child: icon,
    );
  }
}
