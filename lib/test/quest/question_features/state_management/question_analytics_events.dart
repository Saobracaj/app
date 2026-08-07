sealed class QuestionAnalyticsEvent {}

/// Load the analytics for the tab's question. [languageCode] picks the keyword
/// marker set, which is language-specific.
class QuestionAnalyticsRequested extends QuestionAnalyticsEvent {
  QuestionAnalyticsRequested(this.languageCode);

  final String languageCode;
}
