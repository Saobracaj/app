import 'package:freezed_annotation/freezed_annotation.dart';

part 'konspekt.freezed.dart';

part 'konspekt.g.dart';

/// A localized markdown/text value: the Russian and Serbian versions of one
/// fragment, either of which may not be authored yet.
@freezed
abstract class KonspektText with _$KonspektText {
  const KonspektText._();

  const factory KonspektText({String? ru, String? sr}) = _KonspektText;

  factory KonspektText.fromJson(Map<String, dynamic> json) =>
      _$KonspektTextFromJson(json);

  /// RU-first pick, used where no user context exists (authoring validation).
  /// Display code must use [select] — the shown language is decided by the
  /// `russian_content` feature, not by which fragment happens to exist.
  String get text => ru ?? sr ?? '';

  /// The fragment for the study-content language: Russian when the
  /// `russian_content` feature is resolved on (backend grant + the user's
  /// popup/settings opt-in), Serbian otherwise. Falls back to the other
  /// language while the preferred one is not authored yet.
  String select({required bool russian}) =>
      russian ? (ru ?? sr ?? '') : (sr ?? ru ?? '');
}

/// A placeholder for an illustration/animation that will be produced later
/// from [description]. Referenced from section markdown as
/// `![alt](illustration:<id>)`.
@freezed
abstract class KonspektIllustration with _$KonspektIllustration {
  const factory KonspektIllustration({
    required String id,
    required String type,
    KonspektText? description,
  }) = _KonspektIllustration;

  factory KonspektIllustration.fromJson(Map<String, dynamic> json) =>
      _$KonspektIllustrationFromJson(json);
}

/// One fragment of a section: a self-contained piece of its markdown mapped
/// to the questions it answers. `questionIds` may be empty for context-only
/// text (a section's lead-in) — such blocks appear on the full konspekt page
/// but are never excerpted for a question.
@freezed
abstract class KonspektBlock with _$KonspektBlock {
  const factory KonspektBlock({
    required KonspektText content,
    @Default([]) List<int> questionIds,
  }) = _KonspektBlock;

  factory KonspektBlock.fromJson(Map<String, dynamic> json) =>
      _$KonspektBlockFromJson(json);
}

/// One deep-linkable part of a konspekt. Addressed as
/// `/konspekt?category=<categoryId>&section=<id>`.
///
/// `blocks`, when present, is an ordered partition of [content]: joining the
/// blocks' texts with blank lines reproduces it, and the union of the blocks'
/// `questionIds` equals the section's. Documents published before schema v2
/// have no blocks — consumers must fall back to the whole [content].
@freezed
abstract class KonspektSection with _$KonspektSection {
  const factory KonspektSection({
    required String id,
    required KonspektText title,
    required KonspektText content,
    @Default([]) List<KonspektBlock> blocks,
    @Default([]) List<KonspektIllustration> illustrations,
    @Default([]) List<int> questionIds,
  }) = _KonspektSection;

  factory KonspektSection.fromJson(Map<String, dynamic> json) =>
      _$KonspektSectionFromJson(json);
}

/// The glossary of key Serbian exam terms with translations (markdown table).
@freezed
abstract class KonspektDictionary with _$KonspektDictionary {
  const factory KonspektDictionary({
    required KonspektText title,
    required KonspektText content,
  }) = _KonspektDictionary;

  factory KonspektDictionary.fromJson(Map<String, dynamic> json) =>
      _$KonspektDictionaryFromJson(json);
}

/// Study notes ("конспект") for one question category, downloaded from
/// `saobracaj_backend` (see [KonspektRepository]) and authored as
/// `konspekt_content/<categoryId>.json`.
@freezed
abstract class Konspekt with _$Konspekt {
  const factory Konspekt({
    @Default(1) int version,
    required String categoryId,
    required KonspektText categoryName,
    KonspektText? intro,
    @Default([]) List<KonspektSection> sections,
    KonspektDictionary? dictionary,

    /// The document is a **preview** — the backend sent the intro, the section
    /// titles and the first block only, because the reader has no entitlement
    /// for this category. Not part of the authored JSON; set from the GraphQL
    /// `locked` field and never cached.
    @Default(false)
    @JsonKey(includeFromJson: false, includeToJson: false)
    bool locked,
  }) = _Konspekt;

  factory Konspekt.fromJson(Map<String, dynamic> json) =>
      _$KonspektFromJson(json);
}
