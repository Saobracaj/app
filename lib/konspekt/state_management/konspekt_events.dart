sealed class KonspektEvent {}

/// Load the konspekt for the page's category.
class KonspektStarted extends KonspektEvent {}

/// Scroll the viewer to the section with [sectionId] (deep link or an inline
/// cross-section link).
class KonspektSectionRequested extends KonspektEvent {
  KonspektSectionRequested(this.sectionId, {this.onOpen = false});

  final String sectionId;

  /// The jump the page opens with (deep link, the question's konspekt tab) —
  /// reported as part of `konspekt_opened`, not as a jump of its own.
  final bool onOpen;
}
