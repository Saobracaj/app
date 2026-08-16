import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/models/models.dart';

part 'quest_content_bloc.freezed.dart';

/// Per-question state for the exam ("quest") flow: which choices are selected
/// and whether the correct answers are revealed.
///
/// One instance lives for the whole run; [QuestionChanged] swaps it to the next
/// question (the bloc used to be recreated per question via a keyed provider,
/// but that also recreated the progress strip and killed its collapse
/// animation).
class QuestContentBloc extends Bloc<QuestContentEvent, QuesContentState> {
  int questionId;

  /// «Режим презентации»: каждый вопрос открывается уже раскрытым — как будто
  /// «показать ответ» нажали заранее, — и остаётся таким при переходах.
  final bool presentation;

  QuestContentBloc(
    Set<Choice> choices,
    Set<Choice> currentAnswers,
    this.questionId, {
    bool revealAnswers = false,
    this.presentation = false,
  }) : super(
         QuesContentState(
           choices: choices,
           selectedChoices: currentAnswers,
           // Deep links into the discussion reveal the feature tabs (which host
           // the comments) immediately, without requiring an attempt first.
           showCorrectAnswers: revealAnswers || presentation,
         ),
       ) {
    on<AddChoice>(_onAddChoise);
    on<ShowCorrectAnswers>(_onShowCorrectAnswers);
    on<QuestionChanged>(_onQuestionChanged);
  }

  /// Full reset for the newly shown question: selection must not leak between
  /// questions, and a previously recorded answer comes back pre-selected.
  void _onQuestionChanged(
    QuestionChanged event,
    Emitter<QuesContentState> emit,
  ) {
    questionId = event.questionId;
    emit(
      QuesContentState(
        choices: event.choices,
        selectedChoices: event.currentAnswers,
        showCorrectAnswers: presentation,
      ),
    );
  }

  /// Выбор ограничен количеством верных вариантов: лишний тап ничего не
  /// выбирает, а только увеличивает [QuesContentState.limitHits] — по этому
  /// счётчику экран показывает подсказку с вибрацией.
  void _onAddChoise(AddChoice event, Emitter<QuesContentState> emit) {
    final limit = state.choices.where((element) => element.isCorrect).length;
    if (limit > 1) {
      if (state.selectedChoices.contains(event.choice)) {
        emit(
          state.copyWith(
            selectedChoices: {...state.selectedChoices}..remove(event.choice),
          ),
        );
      } else if (state.selectedChoices.length < limit) {
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

/// The run moved to another question — reset the bloc to it.
class QuestionChanged extends QuestContentEvent {
  final Set<Choice> choices;
  final Set<Choice> currentAnswers;
  final int questionId;

  QuestionChanged(this.choices, this.currentAnswers, this.questionId);
}

@freezed
sealed class QuesContentState with _$QuesContentState {
  const factory QuesContentState({
    @Default({}) Set<Choice> choices,
    @Default({}) Set<Choice> selectedChoices,
    @Default(false) bool showCorrectAnswers,

    /// Сколько раз пользователь пытался выбрать вариант сверх лимита. Само
    /// значение не важно — важно, что оно меняется: каждое изменение экран
    /// отрабатывает как разовый эффект (вибрация + подсказка).
    @Default(0) int limitHits,
  }) = _QuesContentState;
}
