sealed class KonspektEvent {}

/// Load the konspekt for the page's category.
class KonspektStarted extends KonspektEvent {}

/// Scroll the viewer to the section with [sectionId] (deep link or an inline
/// cross-section link).
class KonspektSectionRequested extends KonspektEvent {
  KonspektSectionRequested(this.sectionId);

  final String sectionId;
}
