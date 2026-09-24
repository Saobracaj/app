import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/models/models.dart';

part 'practice_content_bloc.freezed.dart';

/// Per-question state for the exam-simulation ("practice") flow: which choices
/// are selected and whether the correct answers have been revealed. Unlike the
/// quest flow it caps multi-select at the number of correct choices and doesn't
/// load the previous-attempts history.
class PracticeContentBloc
    extends Bloc<PracticeContentEvent, PracticeContentState> {
  final int questionId;

  /// [showCorrectAnswers] — верные ответы на этом вопросе уже раскрыты
  /// (продолженная симуляция: раскрыли здесь до паузы или на другом
  /// устройстве).
  PracticeContentBloc(
    Set<Choice> choices,
    Set<Choice> currentAnswers,
    this.questionId, {
    bool showCorrectAnswers = false,
  }) : super(
         PracticeContentState(
           choices: choices,
           selectedChoices: currentAnswers,
           showCorrectAnswers: showCorrectAnswers,
         ),
       ) {
    on<AddChoice>(_onAddChoise);
    on<ShowCorrectAnswers>(_onShowCorrectAnswers);
    on<RestoreSelection>(_onRestoreSelection);
  }

  /// Лишний тап (сверх количества верных вариантов) не выбирается, но и не
  /// пропадает бесследно: он поднимает [PracticeContentState.limitHits], по
  /// которому экран даёт вибрацию и подсказку.
  void _onAddChoise(AddChoice event, Emitter<PracticeContentState> emit) {
    var correctChoices = state.choices.where((element) => element.isCorrect);
    if (correctChoices.length > 1) {
      if (state.selectedChoices.contains(event.choice)) {
        emit(
          state.copyWith(
            selectedChoices: {...state.selectedChoices}..remove(event.choice),
          ),
        );
      } else if (correctChoices.length > state.selectedChoices.length) {
        emit(
          state.copyWith(
            selectedChoices: {...state.selectedChoices, event.choice},
          ),
        );
      } else {
        emit(state.copyWith(limitHits: state.limitHits + 1));
      }
    } else {
      emit(state.copyWith(selectedChoices: {event.choice}));
    }
  }

  void _onShowCorrectAnswers(
    ShowCorrectAnswers event,
    Emitter<PracticeContentState> emit,
  ) {
    emit(state.copyWith(showCorrectAnswers: true));
  }

  void _onRestoreSelection(
    RestoreSelection event,
    Emitter<PracticeContentState> emit,
  ) {
    emit(state.copyWith(selectedChoices: event.choices));
  }
}

sealed class PracticeContentEvent {}

class AddChoice extends PracticeContentEvent {
  final Choice choice;

  AddChoice(this.choice);
}

class ShowCorrectAnswers extends PracticeContentEvent {}

/// Выбор на этом вопросе изменился не с этой страницы — со снимка другого
/// устройства, отражающего идущую там симуляцию; выбор подгоняется под него.
class RestoreSelection extends PracticeContentEvent {
  final Set<Choice> choices;

  RestoreSelection(this.choices);
}

@freezed
sealed class PracticeContentState with _$PracticeContentState {
  const factory PracticeContentState({
    @Default({}) Set<Choice> choices,
    @Default({}) Set<Choice> selectedChoices,
    @Default(false) bool showCorrectAnswers,
    @Default([]) List<bool> previousTries,

    /// Счётчик отклонённых «лишних» тапов; меняется — значит нужно показать
    /// разовую подсказку с вибрацией.
    @Default(0) int limitHits,
  }) = _PracticeContentState;
}
