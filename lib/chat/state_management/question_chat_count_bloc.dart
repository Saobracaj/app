import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/chat_repository.dart';
import 'question_chat_count_events.dart';
import 'question_chat_count_state.dart';

/// Сколько сообщений в обсуждении вопроса — значок на вкладке.
///
/// Отдельно от [ChatBloc]: значок живёт на полосе вкладок, снаружи содержимого
/// вкладки, где работает сам чат, и нужен ему один-единственный скаляр. Спросить
/// его — не то же самое, что открыть разговор: счётчик не создаёт чата.
@injectable
class QuestionChatCountBloc
    extends Bloc<QuestionChatCountEvent, QuestionChatCountState> {
  QuestionChatCountBloc(this._chat, @factoryParam this.questionId)
    : super(const QuestionChatCountState()) {
    on<QuestionChatCountRequested>((event, emit) async {
      try {
        emit(
          QuestionChatCountState(
            count: await _chat.questionChatMessageCount(questionId),
          ),
        );
      } catch (_) {
        // Значок — не то, ради чего стоит показывать ошибку: не прочитался,
        // значит его просто нет.
      }
    });
  }

  final ChatRepository _chat;
  final int questionId;
}
