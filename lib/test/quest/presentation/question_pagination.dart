import 'package:flutter/material.dart';
import 'package:saobracaj/theme/quiz_colors.dart';

import 'question_progress_strip.dart';

/// Пагинация по вопросам прогона — раскрытая строка номеров внизу страницы.
///
/// Заменяет собой полосу прогресса под шапкой на веб-версии: мышью удобнее
/// нажать на номер, чем раскрывать полосу потягом, а сама полоса на широком
/// экране только отъедала место под шапкой.
///
/// Длинный прогон (в экзаменационной категории их бывает под полторы сотни) не
/// влезает в строку целиком, поэтому номера сворачиваются вокруг текущего:
/// первый, многоточие, окно соседей, многоточие, последний. Многоточие — не
/// украшение, а кнопка: она перелистывает окно к следующей/предыдущей пачке
/// номеров, так что до любого вопроса можно дойти, ни разу не промахнувшись
/// мимо цели.
class QuestionPagination extends StatelessWidget {
  const QuestionPagination({
    super.key,
    required this.entries,
    required this.currentQuestionId,
    required this.onQuestionSelected,
  });

  final List<QuestionNavigatorEntry> entries;
  final int currentQuestionId;
  final ValueChanged<int> onQuestionSelected;

  static const double _chipWidth = 40;
  static const double _chipHeight = 32;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    // Один вопрос — переключать нечего.
    if (entries.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final current = entries.indexWhere(
      (e) => e.questionId == currentQuestionId,
    );

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Сколько номеров помещается в строку; меньше пяти окно
                  // сворачивать уже некуда, поэтому это нижняя граница.
                  final fits =
                      ((constraints.maxWidth + _gap) / (_chipWidth + _gap))
                          .floor();
                  final slots = fits < 5 ? 5 : fits;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final slot in paginationSlots(
                        count: entries.length,
                        current: current < 0 ? 0 : current,
                        slots: slots,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _gap / 2,
                          ),
                          child: slot.index != null
                              ? _NumberChip(
                                  entry: entries[slot.index!],
                                  current: slot.index == current,
                                  onTap: () => onQuestionSelected(
                                    entries[slot.index!].questionId,
                                  ),
                                )
                              : _EllipsisChip(
                                  onTap: () => onQuestionSelected(
                                    entries[slot.jumpTo!].questionId,
                                  ),
                                ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Место в строке пагинации: номер вопроса или многоточие-перелистыватель.
class PaginationSlot {
  const PaginationSlot.number(int this.index) : jumpTo = null;
  const PaginationSlot.ellipsis(int this.jumpTo) : index = null;

  /// Индекс вопроса, чей номер стоит в этом месте.
  final int? index;

  /// Индекс вопроса, к которому перелистывает многоточие.
  final int? jumpTo;
}

/// Раскладка строки пагинации на [slots] мест для [count] вопросов, когда
/// открыт вопрос с индексом [current].
///
/// Пока номера влезают — они все и стоят. Дальше строка сворачивается вокруг
/// текущего: первый номер, окно соседей и последний, а между ними многоточия,
/// перелистывающие окно. Результат никогда не длиннее [slots].
List<PaginationSlot> paginationSlots({
  required int count,
  required int current,
  required int slots,
}) {
  if (count <= slots) {
    return [for (var i = 0; i < count; i++) PaginationSlot.number(i)];
  }
  // Два места забирают первый и последний номер, ещё два — многоточия.
  final window = slots - 4 < 1 ? 1 : slots - 4;
  var left = current - window ~/ 2;
  var right = left + window - 1;
  if (left < 1) {
    left = 1;
    right = left + window - 1;
  }
  if (right > count - 2) {
    right = count - 2;
    left = right - window + 1 < 1 ? 1 : right - window + 1;
  }
  return [
    const PaginationSlot.number(0),
    if (left > 1) PaginationSlot.ellipsis(left - 1),
    for (var i = left; i <= right; i++) PaginationSlot.number(i),
    if (right < count - 2) PaginationSlot.ellipsis(right + 1),
    PaginationSlot.number(count - 1),
  ];
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({
    required this.entry,
    required this.current,
    required this.onTap,
  });

  final QuestionNavigatorEntry entry;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    // Те же цвета, что у полосы прогресса: пройденные вопросы читаются
    // одинаково, где бы они ни были нарисованы.
    final (background, foreground) = current
        ? (theme.colorScheme.primary, theme.colorScheme.onPrimary)
        : switch (entry.status) {
            QuestionStatus.unanswered => (quiz.unanswered, quiz.onUnanswered),
            QuestionStatus.correct => (quiz.correct, quiz.onCorrect),
            QuestionStatus.wrong => (quiz.wrong, quiz.onWrong),
          };
    return _Chip(
      background: background,
      onTap: onTap,
      child: Text(
        '${entry.number}',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _EllipsisChip extends StatelessWidget {
  const _EllipsisChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Chip(
      background: Colors.transparent,
      onTap: onTap,
      child: Text(
        '…',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.background,
    required this.onTap,
    required this.child,
  });

  final Color background;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(QuestionPagination._chipHeight / 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuestionPagination._chipHeight / 2),
        child: SizedBox(
          width: QuestionPagination._chipWidth,
          height: QuestionPagination._chipHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}
