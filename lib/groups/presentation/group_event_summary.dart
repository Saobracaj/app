/// One-line wording for a feed event.
///
/// The server names the event and hands over structured details (it has no idea
/// which of the three languages the reader uses), so every sentence is built
/// here from `groups.event.*`. The lines are deliberately short and
/// gender-neutral — they go into a card on the home screen and into the feed
/// list, both of which give an event one line.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../generated/locale_keys.g.dart';
import '../../questions/state_management/all_questions_bloc.dart';
import '../models/group_event.dart';

/// The sentence shown for [event]. [context] is used to resolve subcategory
/// names from the loaded question data; an id that cannot be resolved (the
/// questions are still loading) is shown as-is.
String groupEventSummary(BuildContext context, GroupEvent event) {
  final actor = event.actor.displayName;
  final target = event.target?.displayName ?? actor;

  switch (event.kind) {
    case GroupEventKind.memberJoined:
      return LocaleKeys.groups_event_memberJoined.tr(args: [actor]);
    case GroupEventKind.memberRemoved:
      return LocaleKeys.groups_event_memberRemoved.tr(args: [target]);
    case GroupEventKind.memberLeft:
      return LocaleKeys.groups_event_memberLeft.tr(args: [actor]);
    case GroupEventKind.ownerChanged:
      return LocaleKeys.groups_event_ownerChanged.tr(args: [target]);
    case GroupEventKind.groupRenamed:
      return LocaleKeys.groups_event_renamed.tr(
        args: [event.rename?.name ?? ''],
      );
    case GroupEventKind.subcategoryCompleted:
      final details = event.subcategory;
      if (details == null) return actor;
      return LocaleKeys.groups_event_subcategoryCompleted.tr(
        args: [
          actor,
          subcategoryTitle(context, details.subcategory),
          '${details.rightAnswers}',
          '${details.allAnswers}',
        ],
      );
    case GroupEventKind.practiceFinished:
      final details = event.practice;
      if (details == null) return actor;
      final key = details.passed
          ? LocaleKeys.groups_event_practicePassed
          : LocaleKeys.groups_event_practiceFailed;
      return key.tr(args: [actor, '${details.points}']);
    case GroupEventKind.achievementUnlocked:
      return _achievementSummary(context, event, actor);
    case GroupEventKind.unknown:
      return '';
  }
}

String _achievementSummary(
  BuildContext context,
  GroupEvent event,
  String actor,
) {
  final details = event.achievement;
  if (details == null) return actor;
  switch (details.achievement) {
    case GroupAchievement.firstPracticePass:
      return LocaleKeys.groups_event_firstPracticePass.tr(args: [actor]);
    case GroupAchievement.flawlessSubcategory:
      return LocaleKeys.groups_event_flawlessSubcategory.tr(
        args: [actor, subcategoryTitle(context, details.subcategory)],
      );
    case GroupAchievement.almostFlawlessSubcategory:
      return LocaleKeys.groups_event_almostFlawlessSubcategory.tr(
        args: [actor, subcategoryTitle(context, details.subcategory)],
      );
    case GroupAchievement.practiceStreak:
      return LocaleKeys.groups_event_practiceStreak.tr(
        args: [actor, '${details.streak ?? 2}'],
      );
    case GroupAchievement.unknown:
      return '';
  }
}

/// The human name of a subcategory (its `Description` in the bundled question
/// data), falling back to the raw id while the questions are still loading.
String subcategoryTitle(BuildContext context, String? subcategoryId) {
  final id = subcategoryId ?? '';
  if (id.isEmpty) return '';
  final data = context.read<AllQuestionsBloc>().state.questionsData;
  if (data == null) return id;
  final numericId = int.tryParse(id);
  if (numericId == null) return id;
  for (final category in data.categories) {
    for (final subcategory in category.subcategories) {
      if (subcategory.id == numericId) return subcategory.description;
    }
  }
  return id;
}
