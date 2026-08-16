import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';

part 'history_bloc.freezed.dart';

/// Loads the questions whose most recent answer was wrong, for the "recent
/// mistakes" list on the statistics screen.
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final List<Question> allQuestions;

  HistoryBloc(this.allQuestions) : super(HistoryState()) {
    on<Init>(_init);
    add(Init());
  }

  void _init(Init event, Emitter<HistoryState> emit) async {
    final res = await repository.getQuestionsWhereLastAnswerWasWrong();
    final byId = {for (final q in allQuestions) q.id: q};
    // The history outlives the bank: a question answered before a content
    // update may no longer exist, and looking it up unconditionally would
    // crash the whole screen. Such ids are simply dropped from the list.
    final arr = [for (final qid in res) ?byId[qid]];

    emit(state.copyWith(questions: arr));
  }
}

sealed class HistoryEvent {}

class Init extends HistoryEvent {}

@freezed
sealed class HistoryState with _$HistoryState {
  const factory HistoryState({@Default([]) List<Question> questions}) =
      _HistoryState;
}
