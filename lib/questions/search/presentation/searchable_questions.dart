import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/categories.dart';
import 'package:saobracaj/core/presentation/dismiss_focus.dart';
import 'package:saobracaj/core/responsive.dart';
import 'package:saobracaj/questions/presentation/question_list_tile.dart';
import 'package:saobracaj/questions/questions_page.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';

import '../state_management/question_search_bloc.dart';
import '../state_management/question_search_events.dart';
import '../state_management/question_search_state.dart';

/// The questions page body when the `question_search` feature is on: a search
/// field pinned to the top, and — depending on the query — either the normal
/// category list (empty query) or the grouped search results.
class SearchableQuestions extends StatelessWidget {
  const SearchableQuestions({
    super.key,
    this.wide = false,
    this.showTitle = false,
  });

  /// Раскладка широкого экрана: поиск переезжает в закреплённую шапку рядом с
  /// заголовком, категории показываются плитками.
  final bool wide;

  /// Показывать ли заголовок страницы в шапке — на широких окнах с боковой
  /// колонкой шапки [AppBar] нет, и заголовок несёт сама страница.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AllQuestionsBloc, AllQuestionsBlocState>(
      builder: (context, qState) {
        final data = qState.questionsData;
        // Until the questions have loaded (or on error) there is nothing to
        // search; `Categories` already renders the loading/error states.
        if (data == null) return Categories(wide: wide);
        return BlocProvider(
          create: (_) => QuestionSearchBloc(data),
          child: _SearchableQuestionsView(wide: wide, showTitle: showTitle),
        );
      },
    );
  }
}

class _SearchableQuestionsView extends StatelessWidget {
  const _SearchableQuestionsView({required this.wide, required this.showTitle});

  final bool wide;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      // Нажатие мимо поля поиска (по пустому месту шапки, списка категорий или
      // результатов) снимает фокус — иначе на мобильных клавиатура остаётся
      // висеть над результатами.
      return DismissFocusOnTap(
        child: Column(
          children: [
            QuestionsWideHeader(
              showTitle: showTitle,
              trailing: const _SearchField(),
            ),
            BlocBuilder<QuestionSearchBloc, QuestionSearchState>(
              builder: (context, state) {
                if (!state.isActive || state.matchCount == 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _ResultsCount(count: state.matchCount),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<QuestionSearchBloc, QuestionSearchState>(
                builder: (context, state) {
                  if (!state.isActive) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 26),
                      child: Categories(wide: true),
                    );
                  }
                  if (state.groups.isEmpty) return const _NoResults();
                  return ReadableWidth(
                    child: _SearchResults(groups: state.groups),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    return DismissFocusOnTap(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _SearchField(),
          ),
          BlocBuilder<QuestionSearchBloc, QuestionSearchState>(
            builder: (context, state) {
              // When there are no hits the `_NoResults` placeholder already
              // conveys that, so the count line only shows for non-empty results.
              if (!state.isActive || state.matchCount == 0) {
                return const SizedBox.shrink();
              }
              return _ResultsCount(count: state.matchCount);
            },
          ),
          Expanded(
            child: BlocBuilder<QuestionSearchBloc, QuestionSearchState>(
              builder: (context, state) {
                if (!state.isActive) return const Categories();
                if (state.groups.isEmpty) return const _NoResults();
                return _SearchResults(groups: state.groups);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field driving the search. A tiny [StatefulWidget] purely to own the
/// [TextEditingController] (needed for the clear button); it holds no business
/// logic — every keystroke is forwarded to [QuestionSearchBloc].
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: (value) =>
          context.read<QuestionSearchBloc>().add(QueryChanged(value)),
      decoration: InputDecoration(
        hintText: 'Поиск по вопросам',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                context.read<QuestionSearchBloc>().add(QueryChanged(''));
              },
            );
          },
        ),
      ),
    );
  }
}

/// A small caption under the search field with the number of matching
/// questions for the current query (e.g. "Найдено 3 вопроса").
class _ResultsCount extends StatelessWidget {
  const _ResultsCount({required this.count});

  final int count;

  /// Russian plural form of "вопрос" agreeing with [count].
  String _questionsWord(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'вопросов';
    switch (n % 10) {
      case 1:
        return 'вопрос';
      case 2:
      case 3:
      case 4:
        return 'вопроса';
      default:
        return 'вопросов';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Найдено $count ${_questionsWord(count)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.groups});

  final List<QuestionSearchGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Пролистывание результатов — тоже способ сказать «я закончил печатать»:
      // клавиатура уходит, освобождая пол-экрана под сами результаты.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        for (final group in groups) ...[
          const SizedBox(height: 16),
          ListTile(
            title: Text(
              group.categoryName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final question in group.questions)
            QuestionListTile(
              question: question,
              onTap: () => Routemaster.of(
                context,
              ).push('/quest?q=${question.id}&randomOptionsOrder=true'),
            ),
        ],
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Ничего не найдено',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
