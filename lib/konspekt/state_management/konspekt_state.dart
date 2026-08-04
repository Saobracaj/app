import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';

part 'konspekt_state.freezed.dart';

@freezed
sealed class KonspektState with _$KonspektState {
  const KonspektState._();

  const factory KonspektState({
    Konspekt? konspekt,
    @Default(true) bool inProgress,
    String? errorMessage,

    /// One-shot scroll target: index in the scrollable item list (intro first
    /// when present, then the sections). Emitted and immediately reset.
    int? scrollTo,
  }) = _KonspektState;

  bool get hasIntro => konspekt?.intro != null;

  /// Items of the viewer list: the intro (when present) followed by sections.
  int get itemCount => konspekt == null ? 0 : (hasIntro ? 1 : 0) + konspekt!.sections.length;

  /// Index of [sectionId] in the viewer list, or `null` if unknown.
  int? indexOfSection(String sectionId) {
    final sections = konspekt?.sections;
    if (sections == null) return null;
    final index = sections.indexWhere((s) => s.id == sectionId);
    if (index == -1) return null;
    return index + (hasIntro ? 1 : 0);
  }
}
