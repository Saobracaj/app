/// The activity-feed events of a group, mirroring the `GroupEvent` GraphQL type
/// in `saobracaj_backend` (`src/groups/model.rs`).
///
/// The server never sends ready-made sentences — it names the event kind and
/// hands over structured details, and the client turns that into text in the
/// user's language (en/ru/sr). A kind this build does not know about is parsed
/// as [GroupEventKind.unknown] and simply not rendered, so an older app keeps
/// working against a newer backend.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../statistics/phantom_subcategory.dart';

part 'group_event.freezed.dart';

/// What happened. The wire spellings are the GraphQL enum values (async-graphql
/// renders variants in SCREAMING_SNAKE_CASE) and are part of the API contract.
enum GroupEventKind {
  memberJoined('MEMBER_JOINED'),
  memberRemoved('MEMBER_REMOVED'),
  memberLeft('MEMBER_LEFT'),
  ownerChanged('OWNER_CHANGED'),
  groupRenamed('GROUP_RENAMED'),
  subcategoryCompleted('SUBCATEGORY_COMPLETED'),
  practiceFinished('PRACTICE_FINISHED'),
  achievementUnlocked('ACHIEVEMENT_UNLOCKED'),

  /// A kind added by a newer server than this build knows.
  unknown('');

  const GroupEventKind(this.wire);

  /// The value as it travels over GraphQL.
  final String wire;

  static GroupEventKind parse(Object? raw) {
    final value = raw?.toString();
    for (final kind in values) {
      if (kind != unknown && kind.wire == value) return kind;
    }
    return unknown;
  }
}

/// How a subcategory result compares with the same person's previous attempt at
/// the same block — the "улучшил / ухудшил" marker in the feed.
enum ResultDelta {
  improved('IMPROVED'),
  worsened('WORSENED'),
  unchanged('UNCHANGED');

  const ResultDelta(this.wire);

  final String wire;

  /// `null` for an absent or unknown value: no marker is shown then.
  static ResultDelta? parse(Object? raw) {
    final value = raw?.toString();
    for (final delta in values) {
      if (delta.wire == value) return delta;
    }
    return null;
  }
}

/// Which achievement a member unlocked.
enum GroupAchievement {
  firstPracticePass('FIRST_PRACTICE_PASS'),
  flawlessSubcategory('FLAWLESS_SUBCATEGORY'),
  almostFlawlessSubcategory('ALMOST_FLAWLESS_SUBCATEGORY'),
  practiceStreak('PRACTICE_STREAK'),

  /// An achievement added by a newer server than this build knows.
  unknown('');

  const GroupAchievement(this.wire);

  final String wire;

  static GroupAchievement parse(Object? raw) {
    final value = raw?.toString();
    for (final achievement in values) {
      if (achievement != unknown && achievement.wire == value) {
        return achievement;
      }
    }
    return unknown;
  }
}

/// Whoever an event is about: the person who did it, or the person it was done
/// to. The display name is resolved live, so a renamed member reads correctly in
/// old events.
@freezed
abstract class GroupEventActor with _$GroupEventActor {
  const factory GroupEventActor({
    @Default('') String id,
    @Default('') String displayName,
  }) = _GroupEventActor;

  factory GroupEventActor.fromJson(Map<String, dynamic> json) {
    return GroupEventActor(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
    );
  }
}

/// Somebody finished a block of questions.
@freezed
abstract class SubcategoryCompletedDetails with _$SubcategoryCompletedDetails {
  const factory SubcategoryCompletedDetails({
    /// The subcategory id, as the app's question data calls it.
    @Default('') String subcategory,
    @Default(0) int rightAnswers,
    @Default(0) int allAnswers,

    /// `null` when this is the first time this person finished this block.
    ResultDelta? delta,
    int? previousRightAnswers,
    int? previousAllAnswers,
  }) = _SubcategoryCompletedDetails;

  factory SubcategoryCompletedDetails.fromJson(Map<String, dynamic> json) {
    return SubcategoryCompletedDetails(
      subcategory: json['subcategory']?.toString() ?? '',
      rightAnswers: _int(json['rightAnswers']) ?? 0,
      allAnswers: _int(json['allAnswers']) ?? 0,
      delta: ResultDelta.parse(json['delta']),
      previousRightAnswers: _int(json['previousRightAnswers']),
      previousAllAnswers: _int(json['previousAllAnswers']),
    );
  }
}

/// Somebody sat a mock exam.
@freezed
abstract class PracticeFinishedDetails with _$PracticeFinishedDetails {
  const factory PracticeFinishedDetails({
    @Default(0) int points,
    @Default(0) int mistakes,

    /// Whether the score reached the exam's pass mark.
    @Default(false) bool passed,

    /// How long the exam took; `null` for events recorded before the server
    /// started keeping it — the feed then leaves the time out.
    int? durationSeconds,

    /// The questions that gave them trouble.
    @Default(<int>[]) List<int> wrongAnswers,
  }) = _PracticeFinishedDetails;

  factory PracticeFinishedDetails.fromJson(Map<String, dynamic> json) {
    final wrong = json['wrongAnswers'];
    return PracticeFinishedDetails(
      points: _int(json['points']) ?? 0,
      mistakes: _int(json['mistakes']) ?? 0,
      passed: json['passed'] == true,
      durationSeconds: _int(json['durationSeconds']),
      wrongAnswers: wrong is List
          ? wrong.map(_int).whereType<int>().toList()
          : const [],
    );
  }
}

@freezed
abstract class AchievementDetails with _$AchievementDetails {
  const factory AchievementDetails({
    @Default(GroupAchievement.unknown) GroupAchievement achievement,

    /// How long the streak is, for [GroupAchievement.practiceStreak].
    int? streak,

    /// Which block it was, for the two subcategory achievements.
    String? subcategory,
  }) = _AchievementDetails;

  factory AchievementDetails.fromJson(Map<String, dynamic> json) {
    return AchievementDetails(
      achievement: GroupAchievement.parse(json['achievement']),
      streak: _int(json['streak']),
      subcategory: json['subcategory']?.toString(),
    );
  }
}

@freezed
abstract class GroupRenamedDetails with _$GroupRenamedDetails {
  const factory GroupRenamedDetails({
    @Default('') String name,
    @Default('') String previousName,
  }) = _GroupRenamedDetails;

  factory GroupRenamedDetails.fromJson(Map<String, dynamic> json) {
    return GroupRenamedDetails(
      name: json['name']?.toString() ?? '',
      previousName: json['previousName']?.toString() ?? '',
    );
  }
}

/// One feed entry: a [kind] plus whichever detail object that kind carries.
///
/// Deliberately one flat type rather than a sealed hierarchy — it mirrors the
/// backend's single `GroupEvent` type, so a new event kind costs one enum value
/// and one optional field instead of a new class on both sides.
@freezed
abstract class GroupEvent with _$GroupEvent {
  const factory GroupEvent({
    @Default('') String id,
    @Default(GroupEventKind.unknown) GroupEventKind kind,

    /// When it actually happened — for learning events that is the moment on the
    /// device, not the moment it reached the server. Local time.
    required DateTime occurredAt,
    @Default(GroupEventActor()) GroupEventActor actor,

    /// The person the event happened *to*: the removed member, the new owner.
    GroupEventActor? target,
    SubcategoryCompletedDetails? subcategory,
    PracticeFinishedDetails? practice,
    AchievementDetails? achievement,
    GroupRenamedDetails? rename,
  }) = _GroupEvent;

  const GroupEvent._();

  factory GroupEvent.fromJson(Map<String, dynamic> json) {
    return GroupEvent(
      id: json['id']?.toString() ?? '',
      kind: GroupEventKind.parse(json['kind']),
      occurredAt:
          DateTime.tryParse(json['occurredAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      actor:
          _object(json['actor'], GroupEventActor.fromJson) ??
          const GroupEventActor(),
      target: _object(json['target'], GroupEventActor.fromJson),
      subcategory: _object(
        json['subcategory'],
        SubcategoryCompletedDetails.fromJson,
      ),
      practice: _object(json['practice'], PracticeFinishedDetails.fromJson),
      achievement: _object(json['achievement'], AchievementDetails.fromJson),
      rename: _object(json['rename'], GroupRenamedDetails.fromJson),
    );
  }

  /// Whether this build can render the event at all. An event of an unknown kind
  /// — or an unknown achievement — is dropped rather than shown as a blank row.
  ///
  /// So is a subcategory event about the phantom "null" block: older app builds
  /// recorded block-less runs under that name, and a server that has not swept
  /// those rows yet still serves the events derived from them (`block “null”:
  /// 7/7`). There is no block to talk about, so there is nothing to show.
  bool get isRenderable {
    switch (kind) {
      case GroupEventKind.unknown:
        return false;
      case GroupEventKind.achievementUnlocked:
        final details = achievement;
        if (details == null ||
            details.achievement == GroupAchievement.unknown) {
          return false;
        }
        return switch (details.achievement) {
          GroupAchievement.flawlessSubcategory ||
          GroupAchievement.almostFlawlessSubcategory => !isPhantomSubcategory(
            details.subcategory,
          ),
          _ => true,
        };
      case GroupEventKind.subcategoryCompleted:
        return !isPhantomSubcategory(subcategory?.subcategory);
      default:
        return true;
    }
  }
}

int? _int(Object? raw) => (raw as num?)?.toInt();

T? _object<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    raw is Map ? parse(raw.cast<String, dynamic>()) : null;
