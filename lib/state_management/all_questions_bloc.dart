import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:saobracaj/db/dependencies.dart';
import 'package:saobracaj/models/models.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

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
      final results = await Future.wait([
        rootBundle.loadString('assets/categories.json'),
        rootBundle.loadString('assets/allQuestions.json'),
        rootBundle.loadString('assets/practice.json'),
      ]);

      final categoriesJson = jsonDecode(results[0]) as List;
      final questionsJson = jsonDecode(results[1]) as List;
      final practiceJson = jsonDecode(results[2]) as List;

      var categories = categoriesJson.map((e) => Category.fromJson(e)).toList();
      var questions = questionsJson.map((e) => Question.fromJson(e)).map((e) => e.copyWith(id: e.imageId)).toList();
      var practice = (practiceJson)
          .map((e) => (e as List).map((i) => i as int).toList())
          .toList();


      final data = QuestionsData(categories: categories, questions: questions, practice: practice);

      emit(state.copyWith(questionsData: data));
    } on Exception catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void _onLoadStatistics(LoadStatistics event, Emitter<AllQuestionsBlocState> emit) async {
    final allStats = await repository.getAllRecords();
    final res = <String, SubStats>{};
    for (var s in allStats) {
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
  const factory AllQuestionsBlocState({String? errorMessage, QuestionsData? questionsData, @Default({}) Map<String, SubStats> subStats}) =
      _AllQuestionsBlocState;
}

@freezed
sealed class SubStats with _$SubStats {
  const factory SubStats({@Default([]) List<int> answers, @Default(0) int allAnswers}) = _SubStats;
}
