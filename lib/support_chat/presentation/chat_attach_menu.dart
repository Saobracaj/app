import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../question_lists/domain/list_style.dart';
import '../../question_lists/models/question_list.dart';
import '../../question_lists/state_management/question_lists_bloc.dart';
import '../../question_lists/state_management/question_lists_state.dart';
import '../state_management/support_chat_bloc.dart';
import '../state_management/support_chat_events.dart';

/// Меню кнопки «Вложить»: фотография, файл, список вопросов.
///
/// Разделены не ради красоты: у трёх пунктов три разных пути. Фотография идёт
/// через системную галерею и пережимается в JPEG, файл уезжает байт в байт, а
/// список вопросов вообще ничего не загружает — он прикладывается
/// идентификатором, и снимок с него снимает бэкенд в момент отправки.
Future<void> showChatAttachMenu(BuildContext context) async {
  final bloc = context.read<SupportChatBloc>();
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
              bloc.add(SupportChatPhotosPicked());
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text('support.attachFile'.tr()),
            onTap: () {
              Navigator.of(sheetContext).pop();
              bloc.add(SupportChatFilePicked());
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_check),
            title: Text('support.attachList'.tr()),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final list = await showQuestionListPicker(context, lists);
              if (list != null) bloc.add(SupportChatListAttached(list));
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
  return showModalBottomSheet<QuestionList>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: lists,
      child: const _QuestionListPicker(),
    ),
  );
}

class _QuestionListPicker extends StatelessWidget {
  const _QuestionListPicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QuestionListsBloc, QuestionListsState>(
      builder: (context, state) {
        final lists = state.customLists;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Text(
                  'support.attachList'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (lists.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Text(
                    'support.noOwnLists'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
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
            ],
          ),
        );
      },
    );
  }
}
