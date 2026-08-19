sealed class QuestionChatCountEvent {}

/// Прочитать счётчик сообщений (посылается один раз при появлении вкладок).
class QuestionChatCountRequested extends QuestionChatCountEvent {}
