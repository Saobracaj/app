import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/models/models.dart';

part 'quest_content_bloc.freezed.dart';

/// Per-question state for the exam ("quest") flow: which choices are selected
/// and whether the correct answers are revealed.
class QuestContentBloc extends Bloc<QuestContentEvent, QuesContentState> {
  final int questionId;

  QuestContentBloc(
    Set<Choice> choices,
    Set<Choice> currentAnswers,
    this.questionId, {
    bool revealAnswers = false,
  }) : super(
         QuesContentState(
           choices: choices,
           selectedChoices: currentAnswers,
           // Deep links into the discussion reveal the feature tabs (which host
           // the comments) immediately, without requiring an attempt first.
           showCorrectAnswers: revealAnswers,
         ),
       ) {
    on<AddChoice>(_onAddChoise);
    on<ShowCorrectAnswers>(_onShowCorrectAnswers);
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
}

sealed class QuestContentEvent {}

class AddChoice extends QuestContentEvent {
  final Choice choice;

  AddChoice(this.choice);
}

class ShowCorrectAnswers extends QuestContentEvent {}

@freezed
sealed class QuesContentState with _$QuesContentState {
  const factory QuesContentState({
    @Default({}) Set<Choice> choices,
    @Default({}) Set<Choice> selectedChoices,
    @Default(false) bool showCorrectAnswers,
  }) = _QuesContentState;
}
