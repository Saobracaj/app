import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';

part 'all_questions_bloc.freezed.dart';

final dio = Dio();

class AllQuestionsBloc extends Bloc<AllQuestionsBlocEvent, AllQuestionsBlocState> {
  AllQuestionsBloc() : super(AllQuestionsBlocState()) {
    on<Load>(_onLoad);
    on<LoadStatistics>(_onLoadStatistics);
    add(LoadStatistics());
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

  void _onLoadStatistics(LoadStatistics event, Emitter<AllQuestionsBlocState> emit) async {
    final allStats = await repository.getAllRecords();
    final res = <String, SubStats>{};
    for(var s in allStats) {
      final prev = res[s.subcategory] ?? SubStats();
      res[s.subcategory] = prev.copyWith(answers: [...prev.answers, s.rightAnswers], allAnswers: max(prev.allAnswers, s.allAnswers));
    }

    emit(state.copyWith(subStats: res));
  }
}

sealed class AllQuestionsBlocEvent {}

class Load extends AllQuestionsBlocEvent {}

class LoadStatistics extends AllQuestionsBlocEvent {}

@freezed
sealed class AllQuestionsBlocState with _$AllQuestionsBlocState {
  const factory AllQuestionsBlocState({String? errorMessage, QuestionsData? questionsData, @Default({}) Map<String, SubStats> subStats}) = _AllQuestionsBlocState;
}

@freezed
sealed class SubStats with _$SubStats {
  const factory SubStats({@Default([]) List<int> answers, @Default(0) int allAnswers}) = _SubStats;

}
