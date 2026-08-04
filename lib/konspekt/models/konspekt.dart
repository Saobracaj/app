import 'package:freezed_annotation/freezed_annotation.dart';

part 'konspekt.freezed.dart';

part 'konspekt.g.dart';

/// A localized markdown/text value. Only `ru` is authored today; `sr` is
/// reserved for a future Serbian version of the konspekts.
@freezed
abstract class KonspektText with _$KonspektText {
  const KonspektText._();

  const factory KonspektText({String? ru, String? sr}) = _KonspektText;

  factory KonspektText.fromJson(Map<String, dynamic> json) => _$KonspektTextFromJson(json);

  String get text => ru ?? sr ?? '';
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

  factory KonspektIllustration.fromJson(Map<String, dynamic> json) => _$KonspektIllustrationFromJson(json);
}

/// One deep-linkable part of a konspekt. Addressed as
/// `/konspekt?category=<categoryId>&section=<id>`.
@freezed
abstract class KonspektSection with _$KonspektSection {
  const factory KonspektSection({
    required String id,
    required KonspektText title,
    required KonspektText content,
    @Default([]) List<KonspektIllustration> illustrations,
    @Default([]) List<int> questionIds,
  }) = _KonspektSection;

  factory KonspektSection.fromJson(Map<String, dynamic> json) => _$KonspektSectionFromJson(json);
}

/// The glossary of key Serbian exam terms with translations (markdown table).
@freezed
abstract class KonspektDictionary with _$KonspektDictionary {
  const factory KonspektDictionary({
    required KonspektText title,
    required KonspektText content,
  }) = _KonspektDictionary;

  factory KonspektDictionary.fromJson(Map<String, dynamic> json) => _$KonspektDictionaryFromJson(json);
}

/// Study notes ("конспект") for one question category, bundled as
/// `assets/konspekt/<categoryId>.json`.
@freezed
abstract class Konspekt with _$Konspekt {
  const factory Konspekt({
    @Default(1) int version,
    required String categoryId,
    required KonspektText categoryName,
    KonspektText? intro,
    @Default([]) List<KonspektSection> sections,
    KonspektDictionary? dictionary,
  }) = _Konspekt;

  factory Konspekt.fromJson(Map<String, dynamic> json) => _$KonspektFromJson(json);
}
