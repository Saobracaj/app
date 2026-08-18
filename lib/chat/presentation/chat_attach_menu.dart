import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/presentation/draggable_sheet.dart';
import '../../question_lists/domain/list_style.dart';
import '../../question_lists/models/question_list.dart';
import '../../question_lists/state_management/question_lists_bloc.dart';
import '../../question_lists/state_management/question_lists_state.dart';
import '../state_management/chat_bloc.dart';
import '../state_management/chat_events.dart';

/// Меню кнопки «Вложить»: фотография, файл, список вопросов.
///
/// Разделены не ради красоты: у трёх пунктов три разных пути. Фотография идёт
/// через системную галерею и пережимается в JPEG, файл уезжает байт в байт, а
/// список вопросов уходит ссылкой шаринга — той же самой, которой списком
/// делятся откуда угодно ещё. Способ приложить список ровно один: получатель
/// видит его текущее содержимое и может сохранить себе, а второй способ (снимок
/// списка отдельным вложением) убран, чтобы одно и то же не выглядело в
/// переписке по-разному.
Future<void> showChatAttachMenu(BuildContext context) async {
  final bloc = context.read<ChatBloc>();
  final lists = context.read<QuestionListsBloc>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: Text('support.attachPhoto'.tr()),
            onTap: () {
              Navigator.of(sheetContext).pop();
              bloc.add(ChatPhotosPicked());
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text('support.attachFile'.tr()),
            onTap: () {
              Navigator.of(sheetContext).pop();
              bloc.add(ChatFilePicked());
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: Text('support.attachList'.tr()),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final list = await showQuestionListPicker(context, lists);
              if (list != null) bloc.add(ChatListShared(list));
            },
          ),
        ],
      ),
    ),
  );
}

/// Выбор одного из **собственных** списков пользователя.
///
/// Автоматические списки («недавние ошибки» и прочие) не показываем: они
/// вычисляются из локальной истории ответов, у получателя их нет, а
/// прикладывать снимок такого списка — значит отправить чужие ошибки под чужим
/// названием.
Future<QuestionList?> showQuestionListPicker(
  BuildContext context,
  QuestionListsBloc lists,
) {
  return showDraggableSheet<QuestionList>(
    context: context,
    initialSize: 0.5,
    builder: (sheetContext, controller) => BlocProvider.value(
      value: lists,
      child: _QuestionListPicker(scrollController: controller),
    ),
  );
}

class _QuestionListPicker extends StatelessWidget {
  const _QuestionListPicker({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuestionListsBloc, QuestionListsState>(
      builder: (context, state) {
        final lists = state.customLists;
        return Column(
          children: [
            Expanded(
              // Прокрутка — контроллером самого листа: внутреннего скроллинга
              // у листа нет, тянется он целиком.
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  const SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      'support.attachList'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (lists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Text(
                        'support.noOwnLists'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (final list in lists)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: list.avatarColor(context),
                          radius: 12,
                        ),
                        title: Text(list.title),
                        subtitle: Text(
                          'support.listQuestions'.plural(
                            list.questionIds.length,
                          ),
                        ),
                        onTap: () =>
                            Navigator.of(context).pop<QuestionList>(list),
                      ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SheetActions(),
          ],
        );
      },
    );
  }
}
