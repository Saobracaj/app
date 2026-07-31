import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/db/dependencies.dart';

/// Loads the previous answer attempts (right/wrong) for a single question, shown
/// as the dotted history strip under a practice question.
class QuestionTriesBloc extends Bloc<QuestionTriesEvent, List<bool>> {
  final int _questionId;
  QuestionTriesBloc(this._questionId) : super([]) {
    on<Init>(_init);
    add(Init());
  }

  void _init(Init event, Emitter<List<bool>> emit) async {
    final res = await repository.getAnswersByQuestionId(_questionId);
    final arr = <bool>[];
    for (var r in res) {
      arr.add(r.isWrong);
    }
    emit(arr);
  }
}

sealed class QuestionTriesEvent {}

class Init extends QuestionTriesEvent {}
