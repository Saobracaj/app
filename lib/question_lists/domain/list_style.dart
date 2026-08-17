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

/// Presentation helpers shared by the home-screen chips, the list screen and the
/// "add to list" menu.
extension QuestionListX on QuestionList {
  /// The title to render: automatic lists are localized by id, custom ones show
  /// the user's own name.
  String get title => switch (id) {
    kRecentMistakesListId => LocaleKeys.questionLists_recentMistakes.tr(),
    kLastExamMistakesListId =>
      LocaleKeys.questionLists_lastExamMistakes.tr(),
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
      kPersonalWeakSpotsListId => scheme.tertiary,
      _ => scheme.primary,
    };
  }

  /// The icon inside the avatar. Automatic lists carry a meaningful glyph;
  /// custom ones are identified by their colour alone.
  IconData? get icon => switch (id) {
    kRecentMistakesListId => Icons.error_outline,
    kLastExamMistakesListId => Icons.assignment_late_outlined,
    kPersonalWeakSpotsListId => Icons.trending_down,
    _ => isAuto ? Icons.list_alt : null,
  };
}
