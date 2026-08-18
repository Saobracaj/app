/// Ссылка на расшаренный список внутри сообщения — тем же чипом, что и
/// приложенный список.
///
/// Ссылку на вопрос чат уже превращает во вложение «вопрос 1234» (это делает
/// бэкенд, разбирая текст). Со списком так не выйдет: список живёт по коду
/// шаринга, его название и цвет знает только запрос `sharedQuestionList`, и
/// узнать их можно лишь в момент показа — поэтому чип грузит превью сам.
///
/// Дальше всё как у вопроса: нажатие открывает bottom sheet с превью, из него
/// кнопка «развернуть» ведёт на полноценный экран списка, а «назад» возвращает
/// в переписку — экран открывается императивным маршрутом поверх чата, потому
/// что `/shared/<code>` — абсолютный путь и через роутер он снёс бы весь стек.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../question_lists/presentation/shared_list_page.dart';
import '../../question_lists/state_management/shared_list_bloc.dart';
import '../../question_lists/state_management/shared_list_events.dart';
import '../../question_lists/state_management/shared_list_state.dart';
import '../../test/quest/preview/question_preview_sheet.dart';


/// Коды шаринга, упомянутые в тексте, в порядке появления и без повторов.
///
/// Узнаём две формы, ровно как их выдаёт `SharedListsRepository.share`:
/// `https://saobracaj.gleb.at/shared/ABCDEFGH` и `saobracaj://shared/ABCDEFGH`.
List<String> sharedListCodesIn(String body) {
  const marker = 'shared/';
  final codes = <String>[];
  var rest = body;
  while (true) {
    final at = rest.indexOf(marker);
    if (at < 0) break;
    // Маркер должен быть частью ссылки, а не словом внутри текста.
    final isLink = at > 0 && rest[at - 1] == '/';
    final after = rest.substring(at + marker.length);
    final code = _leadingCode(after);
    if (isLink && code.isNotEmpty && !codes.contains(code)) codes.add(code);
    rest = after.substring(code.length);
    if (rest.isEmpty) break;
  }
  return codes;
}

/// Код шаринга — восемь заглавных букв и цифр; берём ведущую подстроку из
/// допустимых символов и признаём кодом только правильной длины.
String _leadingCode(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (RegExp(r'[A-Z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else {
      break;
    }
  }
  final code = buffer.toString();
  return code.length == 8 ? code : '';
}

/// Чип одного расшаренного списка: иконка списка, название и цвет владельца.
class SharedListChip extends StatelessWidget {
  const SharedListChip({
    super.key,
    required this.code,
    required this.onSurface,
  });

  final String code;

  /// Цвет текста пузыря, на котором чип нарисован.
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(code),
      create: (_) =>
          getIt<SharedListBloc>(param1: code)..add(SharedListStarted()),
      child: _SharedListChipBody(onSurface: onSurface),
    );
  }
}

class _SharedListChipBody extends StatelessWidget {
  const _SharedListChipBody({required this.onSurface});

  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SharedListBloc, SharedListState>(
      builder: (context, state) {
        final preview = state.preview;
        // Мёртвая ссылка (отозвана, список удалён) — не повод рисовать пустой
        // чип: текст сообщения со ссылкой остаётся на месте и говорит сам за
        // себя.
        if (state.failure != null) return const SizedBox.shrink();
        final color = preview == null || preview.color == 0
            ? Theme.of(context).colorScheme.primary
            : Color(preview.color);
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ActionChip(
            avatar: state.loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : CircleAvatar(backgroundColor: color, radius: 9),
            label: Text(
              preview == null
                  ? 'support.sharedListLoading'.tr()
                  : '${preview.name} · ${preview.questionCount}',
              overflow: TextOverflow.ellipsis,
            ),
            labelStyle: TextStyle(color: onSurface),
            onPressed: preview == null
                ? null
                : () => _openSheet(context, context.read<SharedListBloc>()),
          ),
        );
      },
    );
  }
}

/// Превью списка: название, вопросы и кнопка «развернуть».
void _openSheet(BuildContext context, SharedListBloc bloc) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: bloc,
      child: const _SharedListSheet(),
    ),
  );
}

class _SharedListSheet extends StatelessWidget {
  const _SharedListSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SharedListBloc, SharedListState>(
      builder: (context, state) {
        final preview = state.preview;
        if (preview == null) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final code = state.code;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 8, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: preview.color == 0
                          ? Theme.of(context).colorScheme.primary
                          : Color(preview.color),
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        preview.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'support.expand'.tr(),
                      icon: const Icon(Icons.open_in_full),
                      onPressed: () {
                        // Сначала закрываем лист, потом открываем экран: иначе
                        // «назад» возвращало бы в уже пустой лист.
                        Navigator.of(context).pop();
                        _openScreen(context, code);
                      },
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in preview.questionIds)
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: Text('support.questionChip'.tr(args: ['$id'])),
                        onTap: () => showQuestionPreview(context, id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Экран списка поверх чата. Именно императивным маршрутом: `/shared/<code>` —
/// абсолютный путь, и переход через роутер выбросил бы переписку из стека, а
/// вернуться назад пользователь должен именно в неё.
void _openScreen(BuildContext context, String code) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => SharedListPage(code: code)),
  );
}
