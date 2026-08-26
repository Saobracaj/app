import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saobracaj/core/analytics/analytics_service.dart';
import 'package:saobracaj/models/models.dart';

import 'question_search_events.dart';
import 'question_search_state.dart';

/// Filters the bundled questions by a free-text query and groups the hits by
/// category, for the search field on the questions page.
///
/// Only questions that are actually surfaced inside the app are searchable:
/// the bloc walks [QuestionsData.categories] and considers a question only if
/// its subcategory belongs to one of those categories — questions in
/// categories that aren't listed in the app are never returned. Matching is
/// case-insensitive over the question text and every answer choice (both the
/// original Serbian text and, when present, the Russian translation).
///
/// Built directly from screen data in `BlocProvider(create:)` — it has no
/// injected dependency, so it is not registered with `getIt`.
class QuestionSearchBloc extends Bloc<QuestionSearchEvent, QuestionSearchState> {
  final QuestionsData _data;

  /// Таймер, откладывающий отправку события поиска (см. [_logSearch]).
  Timer? _logDebounce;

  QuestionSearchBloc(this._data) : super(const QuestionSearchState()) {
    on<QueryChanged>(_onQueryChanged);
  }

  void _onQueryChanged(QueryChanged event, Emitter<QuestionSearchState> emit) {
    final normalized = event.query.trim().toLowerCase();
    if (normalized.isEmpty) {
      emit(state.copyWith(query: event.query, groups: const []));
      return;
    }

    final groups = <QuestionSearchGroup>[];
    for (final category in _data.categories) {
      final subcategoryIds = category.subcategories.map((e) => e.id).toSet();
      final matches = _data.questions
          .where((q) => subcategoryIds.contains(q.subcategoryId) && _matches(q, normalized))
          .toList();
      if (matches.isNotEmpty) {
        groups.add(QuestionSearchGroup(categoryName: category.name, questions: matches));
      }
    }

    emit(state.copyWith(query: event.query, groups: groups));
    _logSearch(normalized.length, groups.fold(0, (n, g) => n + g.questions.length));
  }

  /// Событие поиска отправляется, когда человек перестал печатать: обработчик
  /// зовётся на каждый символ, и без этой паузы одна фраза дала бы десяток
  /// одинаковых записей в журнале.
  void _logSearch(int queryLength, int results) {
    _logDebounce?.cancel();
    _logDebounce = Timer(
      const Duration(milliseconds: 900),
      () => analytics.logQuestionSearch(
        queryLength: queryLength,
        results: results,
      ),
    );
  }

  @override
  Future<void> close() {
    _logDebounce?.cancel();
    return super.close();
  }

  bool _matches(Question question, String normalized) {
    if (question.text.toLowerCase().contains(normalized)) return true;
    if ((question.translation ?? '').toLowerCase().contains(normalized)) return true;
    for (final choice in question.choices) {
      if (choice.text.toLowerCase().contains(normalized)) return true;
      if ((choice.translationRu ?? '').toLowerCase().contains(normalized)) return true;
    }
    return false;
  }
}
