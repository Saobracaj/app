import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../generated/locale_keys.g.dart';
import '../data/comment_repository.dart';

/// Админская плашка над комментарием для держателей `edit_comments`: метка
/// состояния (в том числе «черновик не опубликован» поверх уже
/// опубликованного комментария) и действия «Опубликовать» / «Редактировать».
///
/// Виджет намеренно не знает про Bloc и DI — состояние приходит в [details],
/// действия уходят наружу через колбэки, поэтому плашку можно проверить
/// виджет-тестом без поднятия сессии и репозитория.
class CommentEditorPanel extends StatelessWidget {
  const CommentEditorPanel({
    super.key,
    required this.details,
    required this.isPublishing,
    required this.onPublish,
    required this.onEdit,
  });

  /// Загруженный комментарий; `null` — комментария ещё нет.
  final QuestionCommentDetails? details;
  final bool isPublishing;
  final VoidCallback onPublish;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUnpublishedDraft = details?.hasUnpublishedDraft ?? false;

    // У READY-комментария метка нужна только тогда, когда поверх него лежит
    // неопубликованная правка: иначе учащиеся и редактор видят одно и то же.
    final mark = switch (details?.status ?? 'PENDING') {
      'READY' => hasUnpublishedDraft
          ? LocaleKeys.commentAdmin_unpublishedDraft.tr()
          : null,
      'MODERATION' => LocaleKeys.commentAdmin_moderation.tr(),
      'DRAFT' => LocaleKeys.commentAdmin_draft.tr(),
      _ => LocaleKeys.commentAdmin_noComment.tr(),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (mark != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 18,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mark,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          if (details?.canPublish ?? false)
            FilledButton.tonalIcon(
              onPressed: isPublishing ? null : onPublish,
              icon: isPublishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish, size: 18),
              label: Text(
                hasUnpublishedDraft
                    ? LocaleKeys.commentAdmin_publishDraft.tr()
                    : LocaleKeys.commentAdmin_publish.tr(),
              ),
            ),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(LocaleKeys.commentAdmin_edit.tr()),
          ),
        ],
      ),
    );
  }
}
