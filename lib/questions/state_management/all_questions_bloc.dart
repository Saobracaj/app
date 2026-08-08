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
import 'package:collection/collection.dart';

part 'all_questions_bloc.freezed.dart';

final dio = Dio();

class AllQuestionsBloc extends Bloc<AllQuestionsBlocEvent, AllQuestionsBlocState> {
  AllQuestionsBloc() : super(AllQuestionsBlocState()) {
    on<Load>(_onLoad);
    on<LoadStatistics>(_onLoadStatistics);
    add(LoadStatistics());
  }

  StreamSubscription<void>? _syncSubscription;

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }

  void _onLoad(Load event, Emitter<AllQuestionsBlocState> emit) async {
    emit(state.copyWith(errorMessage: null, questionsData: null));

    try {
      // Load raw asset strings on the main isolate (I/O, cheap), then do all
      // the CPU-heavy JSON decoding + join on a background isolate via
      // `compute` so the UI thread never blocks. On web `compute` runs inline,
      // but the work below is now linear (Map index instead of an O(n^2) join),
      // so it stays fast there too.
      final results = await Future.wait([
        rootBundle.loadString('assets/categories.json'),
        rootBundle.loadString('assets/allQuestions.json'),
        rootBundle.loadString('assets/practice.json'),
        rootBundle.loadString('assets/allQuestions_ru.json'),
      ]);

      final data = await compute(
        _parseQuestionsData,
        _RawAssets(
          categories: results[0],
          questions: results[1],
          practice: results[2],
          translations: results[3],
        ),
      );

      emit(state.copyWith(questionsData: data));
    } on Exception catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void _onLoadStatistics(LoadStatistics event, Emitter<AllQuestionsBlocState> emit) async {
    // Login triggers a statistics sync (AuthBloc); the merged records land in
    // the local DB after this handler's one-shot read, so re-read on every
    // completed sync — otherwise the questions screen shows stale (empty)
    // stats until a test is finished or the app restarts. Subscribed here and
    // not in the constructor: the handler already touches the same globals,
    // while test stubs that swallow events never reach them.
    try {
      _syncSubscription ??=
          statisticsSync.synced.listen((_) => add(LoadStatistics()));
    } catch (_) {
      // `statisticsSync` needs the DI container; widget tests run without one,
      // and they don't sync — the refresh is best-effort anyway.
    }
    final allStats = await repository.getAllRecords();
    final res = <String, SubStats>{};
    for (var s in allStats) {
      final prev = res[s.subcategory] ?? SubStats();
      res[s.subcategory] = prev.copyWith(answers: [...prev.answers, s.rightAnswers], allAnswers: max(prev.allAnswers, s.allAnswers));
    }

    emit(state.copyWith(subStats: res));
  }
}

/// Raw asset payload passed to the background isolate.
class _RawAssets {
  const _RawAssets({required this.categories, required this.questions, required this.practice, required this.translations});

  final String categories;
  final String questions;
  final String practice;
  final String translations;
}

/// Runs on a background isolate (`compute`). Decodes all JSON and joins each
/// question with its Russian translation via a `Map` index (O(n) instead of the
/// previous O(n^2) `firstWhereOrNull` scan) so this stays fast on web too.
QuestionsData _parseQuestionsData(_RawAssets raw) {
  final categoriesJson = jsonDecode(raw.categories) as List;
  final questionsJson = jsonDecode(raw.questions) as List;
  final practiceJson = jsonDecode(raw.practice) as List;
  final translationsJson = jsonDecode(raw.translations) as List;

  final categories = categoriesJson.map((e) => Category.fromJson(e)).toList();
  final questions = questionsJson.map((e) => Question.fromJson(e)).map((e) => e.copyWith(id: e.imageId)).toList();
  final practice = practiceJson.map((e) => (e as List).map((i) => i as int).toList()).toList();

  // Index translations by question id for O(1) lookup.
  final translationsById = <int, Translation>{};
  for (final e in translationsJson) {
    final t = Translation.fromJson(e);
    translationsById[t.imageId] = t;
  }

  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    final translation = translationsById[q.id];
    if (translation == null) continue;

    final choicesTranslation = translation.choices;
    // Skip questions whose choice counts don't line up rather than abandoning
    // the whole join (the old `break` stopped translating every later question).
    if (choicesTranslation.length != q.choices.length) continue;

    questions[i] = q.copyWith(
      translation: translation.text,
      choices: q.choices.mapIndexed((index, element) => element.copyWith(translationRu: choicesTranslation[index].text)).toList(),
    );
  }

  return QuestionsData(categories: categories, questions: questions, practice: practice);
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
