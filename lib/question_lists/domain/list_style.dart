import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';
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

  /// The colour of the round leading avatar: the user's pick for a custom list,
  /// a theme colour for an automatic one — each automatic list keeps its own so
  /// they are told apart at a glance in the row.
  Color avatarColor(BuildContext context) {
    if (!isAuto) return Color(color);
    final scheme = Theme.of(context).colorScheme;
    return switch (id) {
      kLastExamMistakesListId => scheme.secondary,
      kChronicMistakesListId => scheme.error,
      kPersonalWeakSpotsListId => scheme.tertiary,
      _ => scheme.primary,
    };
  }

  /// The colour of the glyph drawn inside the avatar. An automatic list sits on
  /// a role colour, so the glyph takes that role's paired `on…` colour: on the
  /// dark theme the roles are light pastels, and a hard-coded white icon all
  /// but disappeared on them. A custom list sits on a colour the user picked
  /// from [kListColors], which does not follow the theme — there the readable
  /// foreground is chosen from the background's own luminance.
  Color avatarForegroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!isAuto) return onListColor(Color(color));
    return switch (id) {
      kLastExamMistakesListId => scheme.onSecondary,
      kChronicMistakesListId => scheme.onError,
      kPersonalWeakSpotsListId => scheme.onTertiary,
      _ => scheme.onPrimary,
    };
  }

  /// The icon inside the avatar. Automatic lists carry a meaningful glyph;
  /// custom ones are identified by their colour alone.
  IconData? get icon => switch (id) {
    kRecentMistakesListId => Icons.error_outline,
    kLastExamMistakesListId => Icons.assignment_late_outlined,
    kChronicMistakesListId => Icons.repeat,
    kPersonalWeakSpotsListId => Icons.trending_down,
    _ => isAuto ? Icons.list_alt : null,
  };
}
