import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';

part 'quest_content_bloc.freezed.dart';

/// Per-question state for the exam ("quest") flow: which choices are selected,
/// whether the correct answers are revealed, and the previous-attempts strip.
class QuestContentBloc extends Bloc<QuestContentEvent, QuesContentState> {
  final int questionId;

  QuestContentBloc(
    Set<Choice> choices,
    Set<Choice> currentAnswers,
    this.questionId,
  ) : super(QuesContentState(choices: choices, selectedChoices: currentAnswers)) {
    on<AddChoice>(_onAddChoise);
    on<ShowCorrectAnswers>(_onShowCorrectAnswers);
    on<GetHistory>(_onGetHistory);
    add(GetHistory());
  }

  void _onAddChoise(AddChoice event, Emitter<QuesContentState> emit) {
    if (state.choices.where((element) => element.isCorrect).length > 1) {
      if (state.selectedChoices.contains(event.choice)) {
        emit(state.copyWith(
          selectedChoices: {...state.selectedChoices}..remove(event.choice),
        ));
      } else {
        emit(state.copyWith(
          selectedChoices: {...state.selectedChoices, event.choice},
        ));
      }
    } else {
      emit(state.copyWith(selectedChoices: {event.choice}));
    }
  }

  void _onShowCorrectAnswers(
    ShowCorrectAnswers event,
    Emitter<QuesContentState> emit,
  ) {
    emit(state.copyWith(showCorrectAnswers: true));
  }

  void _onGetHistory(GetHistory event, Emitter<QuesContentState> emit) async {
    final res = await repository.getAnswersByQuestionId(questionId);
    final arr = <bool>[];
    for (var r in res) {
      arr.add(r.isWrong);
    }
    emit(state.copyWith(previousTries: arr));
  }
}

sealed class QuestContentEvent {}

class AddChoice extends QuestContentEvent {
  final Choice choice;

  AddChoice(this.choice);
}

class ShowCorrectAnswers extends QuestContentEvent {}

class GetHistory extends QuestContentEvent {}

@freezed
sealed class QuesContentState with _$QuesContentState {
  const factory QuesContentState({
    @Default({}) Set<Choice> choices,
    @Default({}) Set<Choice> selectedChoices,
    @Default(false) bool showCorrectAnswers,
    @Default([]) List<bool> previousTries,
  }) = _QuesContentState;
}
