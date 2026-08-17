import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';

/// Ненавязчивая подсказка по клавиатурному управлению вопросами: рисованные
/// клавиши ← / → / пробел с подписью, что каждая делает (см.
/// `KeyboardPagination`, где эти клавиши и обрабатываются).
///
/// Показывается только на вебе — там пользователь сидит за клавиатурой, но не
/// догадывается, что стрелки листают вопросы, а пробел раскрывает ответ. На
/// телефоне и планшете клавиатуры нет, и подсказка не рисуется вовсе (пустой
/// виджет), так что вызывающий код может ставить её безусловно.
///
/// Стоит рядом со строкой навигации внизу экрана — в тренажёре под пагинацией,
/// в симуляции экзамена возле кнопок «Претходно/Следеће» — и намеренно
/// мелкая и блёклая: это справка на полях, а не элемент управления.
class KeyboardHints extends StatelessWidget {
  const KeyboardHints({
    super.key,
    this.navigation = true,
    this.showAnswer = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
  });

  /// Подсказывать ли стрелки (← предыдущий, → следующий). Выключается там,
  /// где листать нечего — в прогоне из одного вопроса.
  final bool navigation;

  /// Подсказывать ли пробел («показать ответ»). Выключается, когда показ
  /// ответов в этом прогоне недоступен (экзамен без тренировочной опции).
  final bool showAnswer;

  final EdgeInsetsGeometry padding;

  /// Принудительно показывать подсказку вне веба — для виджет-тестов, где
  /// `kIsWeb` всегда `false`.
  @visibleForTesting
  static bool debugForceVisible = false;

  /// Есть ли подсказка на этой платформе.
  static bool get visible => kIsWeb || debugForceVisible;

  @override
  Widget build(BuildContext context) {
    if (!visible || (!navigation && !showAnswer)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurfaceVariant.withValues(alpha: 0.7);
    return ExcludeSemantics(
      child: Padding(
        padding: padding,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            if (navigation) ...[
              _Hint(
                keyCap: _KeyCap(icon: Icons.arrow_back, color: color),
                label: LocaleKeys.quest_previous.tr(),
                color: color,
              ),
              _Hint(
                keyCap: _KeyCap(icon: Icons.arrow_forward, color: color),
                label: LocaleKeys.quest_next.tr(),
                color: color,
              ),
            ],
            if (showAnswer)
              _Hint(
                keyCap: _KeyCap(
                  icon: Icons.space_bar,
                  color: color,
                  wide: true,
                ),
                label: LocaleKeys.quest_showAnswer.tr(),
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// Одна строка подсказки: клавиша и что она делает.
class _Hint extends StatelessWidget {
  const _Hint({required this.keyCap, required this.label, required this.color});

  final Widget keyCap;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        keyCap,
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Рисованный колпачок клавиши: тонкая рамка со значком внутри. Пробел —
/// широкий, как на настоящей клавиатуре.
class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.icon, required this.color, this.wide = false});

  final IconData icon;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 34 : 18,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 12, color: color),
    );
  }
}
