import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_chat_count_state.freezed.dart';

/// Сколько сообщений в обсуждении вопроса. Значок на вкладке прячется, пока
/// [count] равен нулю.
@freezed
abstract class QuestionChatCountState with _$QuestionChatCountState {
  const factory QuestionChatCountState({@Default(0) int count}) =
      _QuestionChatCountState;
}
