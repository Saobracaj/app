import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/models/models.dart';

part 'all_questions_bloc.freezed.dart';

final dio = Dio();

class AllQuestionsBloc extends Bloc<AllQuestionsBlocEvent, AllQuestionsBlocState> {
  AllQuestionsBloc() : super(AllQuestionsBlocState()) {
    on<Load>(_onLoad);
  }

  void _onLoad(Load event, Emitter<AllQuestionsBlocState> emit) async {
    emit(state.copyWith(errorMessage: null, questionsData: null));

    try {
      final res = await Future.wait([
        dio.get('https://klgleb.github.io/saobracajData/categories.json'),
        dio.get('https://klgleb.github.io/saobracajData/allQuestions.json'),
      ]);

      var questions = (res[1].data as List).map((e) => Question.fromJson(e)).toList();
      var categories = (res[0].data as List).map((e) => Category.fromJson(e)).toList();


      final data = QuestionsData(categories: categories, questions: questions);

      emit(state.copyWith(questionsData: data));
    } on Exception catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}

sealed class AllQuestionsBlocEvent {}

class Load extends AllQuestionsBlocEvent {}

@freezed
sealed class AllQuestionsBlocState with _$AllQuestionsBlocState {
  const factory AllQuestionsBlocState({String? errorMessage, QuestionsData? questionsData}) =
      _AllQuestionsBlocState;
}
