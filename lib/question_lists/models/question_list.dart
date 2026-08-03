import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_list.freezed.dart';
part 'question_list.g.dart';

/// A named collection of questions shown on the home screen.
///
/// Two kinds share this model:
///   * **automatic** lists ([isAuto] `true`) — derived on the device from the
///     local answer history (currently only "recent mistakes"); they have a
///     synthetic id, a fixed icon colour and are never sent to the backend;
///   * **custom** lists — created by the user, stored in `saobracaj_backend`
///     (`saobracaj_question_lists`) and mirrored into a local cache so the UI
///     can render them instantly and offline.
@freezed
sealed class QuestionList with _$QuestionList {
  const factory QuestionList({
    /// Client-generated UUID for custom lists (the backend stores exactly this
    /// id), or an `auto:*` key for automatic ones.
    required String id,

    /// The user-typed name. Empty for automatic lists, whose title is localized
    /// at render time — see `QuestionListX.title`.
    @Default('') String name,

    /// ARGB colour picked by the user (`Color.toARGB32()`); ignored for
    /// automatic lists, which use the theme's standard colour.
    @Default(0) int color,

    /// The questions, in the order the user arranged them.
    @Default(<int>[]) List<int> questionIds,

    /// Whether this is a device-derived automatic list. Never serialized: the
    /// backend and the local cache only ever hold custom lists.
    @Default(false) @JsonKey(includeFromJson: false, includeToJson: false)
    bool isAuto,
  }) = _QuestionList;

  factory QuestionList.fromJson(Map<String, dynamic> json) =>
      _$QuestionListFromJson(json);
}

/// The id of the only automatic list so far: every question whose most recent
/// answer was wrong (the same set the History screen shows).
const String kRecentMistakesListId = 'auto:recent_mistakes';
