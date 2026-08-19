import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';
import '../../theme/quiz_colors.dart';
import '../models/question_list.dart';

/// The colours offered when creating or editing a custom list. Picked to stay
/// legible as a small filled circle on both the light and the dark theme.
const List<Color> kListColors = [
  Color(0xFFE53935), // red
  Color(0xFFF4511E), // deep orange
  Color(0xFFFB8C00), // orange
  Color(0xFFFDD835), // yellow
  Color(0xFF7CB342), // light green
  Color(0xFF00897B), // teal
  Color(0xFF039BE5), // light blue
  Color(0xFF3949AB), // indigo
  Color(0xFF8E24AA), // purple
  Color(0xFFD81B60), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF546E7A), // blue grey
];

/// A random colour from [kListColors] — the default pre-selected one when the
/// user opens the "create list" dialog.
Color randomListColor() => kListColors[Random().nextInt(kListColors.length)];

/// A random UUID (v4) used as the id of a new custom list. The client owns list
/// ids so a list can be rendered before the backend has confirmed it; the
/// backend stores exactly this value (`createQuestionList(id: …)`).
String genListId() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  // Version 4, variant 1, per RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// The readable ink for something drawn on top of [background]: whichever of
/// white and near-black contrasts with it more. Used for the fixed
/// [kListColors] swatches, which keep their colour in both themes — several of
/// them sit mid-way in luminance, where `estimateBrightnessForColor` still
/// answers "white" and the glyph is the harder one to make out (white on the
/// yellow swatch was unreadable outright).
Color onListColor(Color background) =>
    _contrastRatio(Colors.black87, background) >=
        _contrastRatio(Colors.white, background)
    ? Colors.black87
    : Colors.white;

/// The WCAG contrast ratio between two opaque colours, `(L1 + .05) / (L2 + .05)`.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// Presentation helpers shared by the home-screen chips, the list screen and the
/// "add to list" menu.
extension QuestionListX on QuestionList {
  /// The title to render: automatic lists are localized by id, custom ones show
  /// the user's own name.
  String get title => switch (id) {
    kRecentMistakesListId => LocaleKeys.questionLists_recentMistakes.tr(),
    kLastExamMistakesListId =>
      LocaleKeys.questionLists_lastExamMistakes.tr(),
    kChronicMistakesListId => LocaleKeys.questionLists_chronicMistakes.tr(),
    kPersonalWeakSpotsListId =>
      LocaleKeys.questionLists_personalWeakSpots.tr(),
    _ => name,
  };

  /// Цвет иконки-тайла и цвет самой иконки — всегда пара «цвет / on-цвет»
  /// (требование дизайн-системы, карточка «Списки вопросов»): белая иконка
  /// поверх `primary` не проходила по контрасту на светлом primary тёмной
  /// схемы. Автосписки берут пары из токенов викторины и схемы, у
  /// пользовательских списков цвет произвольный, поэтому on-цвет считается по
  /// яркости — см. [onListColor].
  ListAvatarColors avatarColors(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (!isAuto) {
      final background = Color(color);
      return ListAvatarColors(background, onListColor(background));
    }
    final quiz = theme.quiz;
    // Каждый автосписок держит свою пару, чтобы они различались в ленте с
    // одного взгляда.
    return switch (id) {
      kLastExamMistakesListId => ListAvatarColors(
        scheme.secondary,
        scheme.onSecondary,
      ),
      kChronicMistakesListId => ListAvatarColors(quiz.warning, quiz.onWarning),
      kPersonalWeakSpotsListId => ListAvatarColors(
        scheme.tertiary,
        scheme.onTertiary,
      ),
      // «Последние ошибки» — ошибка викторины и по смыслу, и по цвету.
      _ => ListAvatarColors(quiz.wrong, quiz.onWrong),
    };
  }

  /// Только подложка иконки — для мест, где иконка не рисуется (кружок в меню
  /// вложений чата).
  Color avatarColor(BuildContext context) => avatarColors(context).background;

  /// The icon inside the avatar tile. Automatic lists carry a meaningful
  /// glyph; a custom list is told apart by its colour and gets a neutral one.
  IconData? get icon => switch (id) {
    kRecentMistakesListId => Icons.error_outline,
    kLastExamMistakesListId => Icons.assignment_late_outlined,
    kChronicMistakesListId => Icons.repeat,
    kPersonalWeakSpotsListId => Icons.trending_down,
    // У пользовательского списка своей иконки нет: тайл всё равно должен
    // читаться как иконка, а не как пустой цветной квадрат.
    _ => isAuto ? Icons.list_alt : Icons.label_outline,
  };
}

/// Пара «цвет подложки / цвет иконки» тайла списка.
@immutable
class ListAvatarColors {
  const ListAvatarColors(this.background, this.foreground);

  /// Подложка тайла.
  final Color background;

  /// Цвет иконки поверх [background].
  final Color foreground;
}
