sealed class DailySignEvent {}

class DailySignStarted extends DailySignEvent {}

/// «Показать название»: flip the flashcard.
class DailySignRevealed extends DailySignEvent {}
