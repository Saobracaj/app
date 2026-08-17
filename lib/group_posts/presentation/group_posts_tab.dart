import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/presentation/load_failed.dart';
import '../../core/presentation/pagination.dart';
import '../../generated/locale_keys.g.dart';
import '../../public_comments/presentation/relative_time.dart';
import '../../question_lists/models/question_list.dart';
import '../../question_lists/state_management/question_lists_bloc.dart';
import '../../support_chat/presentation/support_attachment_views.dart';
import '../data/group_posts_repository.dart';
import '../models/group_post.dart';
import '../state_management/group_posts_bloc.dart';
import '../state_management/group_posts_events.dart';
import '../state_management/group_posts_state.dart';
import 'post_comments_sheet.dart';

/// The «Посты» tab of a group: what members wrote, newest first, with a
/// composer under it.
///
/// A post carries the same attachments a support message does — a file, an
/// image, a question, a shared question list — and they are rendered by the same
/// widget ([SupportAttachmentView]); only the query that re-signs an expired
/// link differs, which is what [GroupPostsRepository.attachmentUrl] is passed in
/// for.
class GroupPostsTab extends StatelessWidget {
  const GroupPostsTab({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupPostsBloc, GroupPostsState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!.tr())));
        context.read<GroupPostsBloc>().add(const GroupPostsErrorShown());
      },
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => context.read<GroupPostsBloc>().add(
                  const GroupPostsRefreshed(),
                ),
                child: switch ((state.loaded, state.failed, state.isEmpty)) {
                  // Стена ещё не пришла и прочитать её не удалось: пустая стена
                  // здесь солгала бы («постов ещё нет» вместо «нет связи»), а
                  // индикатор крутился бы вечно — см. [LoadFailedList].
                  (false, true, _) => LoadFailedList(
                    message: state.failedOffline
                        ? LocaleKeys.groups_feed_offline.tr()
                        : LocaleKeys.network_loadFailed.tr(),
                    onRetry: () => context.read<GroupPostsBloc>().add(
                      const GroupPostsRefreshed(),
                    ),
                  ),
                  (false, _, _) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  (_, _, true) => const _EmptyWall(),
                  _ => _PostList(state: state),
                },
              ),
            ),
            const _Composer(),
          ],
        );
      },
    );
  }
}

/// A wall nobody has written on yet. Scrollable, so pull-to-refresh works on it.
class _EmptyWall extends StatelessWidget {
  const _EmptyWall();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Text(
            LocaleKeys.groups_posts_empty.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({required this.state});

  final GroupPostsState state;

  @override
  Widget build(BuildContext context) {
    void loadMore() =>
        context.read<GroupPostsBloc>().add(const GroupPostsMoreRequested());
    return PaginationTrigger(
      enabled: state.hasMore && !state.loadingMore && !state.loading,
      onLoadMore: loadMore,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.posts.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.posts.length) {
            return LoadMoreFooter(
              loading: state.loadingMore,
              onLoadMore: loadMore,
            );
          }
          return GroupPostCard(post: state.posts[index]);
        },
      ),
    );
  }
}

/// One post: who wrote it and when, the text, the attachments, and the way into
/// its comments.
class GroupPostCard extends StatelessWidget {
  const GroupPostCard({super.key, required this.post});

  final GroupPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.authorDisplayName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  relativeTime(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (post.deletableByMe)
                  IconButton(
                    tooltip: LocaleKeys.groups_posts_delete.tr(),
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
            if (post.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: SelectableText(post.body),
              ),
            for (final attachment in post.attachments)
              SupportAttachmentView(
                attachment: attachment,
                onSurface: theme.colorScheme.onSurface,
                resolveUrl: getIt<GroupPostsRepository>().attachmentUrl,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.mode_comment_outlined, size: 18),
                label: Text(
                  post.commentsCount == 0
                      ? LocaleKeys.groups_posts_comment.tr()
                      : LocaleKeys.groups_posts_commentsCount.tr(
                          args: ['${post.commentsCount}'],
                        ),
                ),
                onPressed: () => showPostComments(context, post),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<GroupPostsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocaleKeys.groups_posts_deleteConfirmTitle.tr()),
        content: Text(LocaleKeys.groups_posts_deleteConfirmBody.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(LocaleKeys.groups_cancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(LocaleKeys.groups_posts_delete.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(GroupPostDeleted(post.id));
  }
}

/// What the author is writing: the text, the chips of everything already
/// attached, and the two ways of attaching more.
///
/// The text itself lives in the Bloc (like the support chat's composer), so the
/// send button, the chips and the field never disagree about what is about to
/// be posted.
class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<GroupPostsBloc, GroupPostsState>(
      builder: (context, state) {
        final bloc = context.read<GroupPostsBloc>();
        return SafeArea(
          top: false,
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.hasAttachments)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final attachment in state.pending)
                          InputChip(
                            avatar: Icon(
                              attachment.isImage
                                  ? Icons.image_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            label: Text(
                              attachment.fileName,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => bloc.add(
                              GroupPostAttachmentRemoved(attachment.id),
                            ),
                          ),
                        for (final list in state.pendingLists)
                          InputChip(
                            avatar: const Icon(Icons.playlist_add_check),
                            label: Text(
                              '${list.name} · ${list.questionIds.length}',
                            ),
                            onDeleted: () =>
                                bloc.add(GroupPostAttachmentRemoved(list.id)),
                          ),
                      ],
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: LocaleKeys.groups_posts_attachFile.tr(),
                        onPressed: state.uploading
                            ? null
                            : () => bloc.add(const GroupPostAttachPressed()),
                        icon: state.uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.attach_file),
                      ),
                      IconButton(
                        tooltip: LocaleKeys.groups_posts_attachList.tr(),
                        onPressed: () => _pickList(context, bloc),
                        icon: const Icon(Icons.playlist_add_check),
                      ),
                      Expanded(
                        child: _ComposerField(
                          text: state.body,
                          hint: LocaleKeys.groups_posts_hint.tr(),
                          onChanged: (value) =>
                              bloc.add(GroupPostBodyChanged(value)),
                        ),
                      ),
                      IconButton(
                        onPressed: state.canSubmit
                            ? () => bloc.add(const GroupPostSubmitted())
                            : null,
                        icon: state.submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pick one of the author's own question lists to share. Automatic lists
  /// ("recent mistakes") are left out: they are derived on the device and the
  /// server has nothing to snapshot.
  Future<void> _pickList(BuildContext context, GroupPostsBloc bloc) async {
    final lists = context.read<QuestionListsBloc>().state.customLists;
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.groups_posts_noLists.tr())),
      );
      return;
    }
    final picked = await showModalBottomSheet<QuestionList>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final list in lists)
              ListTile(
                leading: const Icon(Icons.playlist_add_check),
                title: Text(list.name),
                subtitle: Text(
                  LocaleKeys.groups_posts_listQuestions.tr(
                    args: ['${list.questionIds.length}'],
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(list),
              ),
          ],
        ),
      ),
    );
    if (picked != null) bloc.add(GroupPostListAttached(picked));
  }
}

/// The text field. Stateful only to own its `TextEditingController` — the value
/// lives in the Bloc, and the controller is re-synced when the Bloc clears it
/// after a post is published.
class _ComposerField extends StatefulWidget {
  const _ComposerField({
    required this.text,
    required this.hint,
    required this.onChanged,
  });

  final String text;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_ComposerField> createState() => _ComposerFieldState();
}

class _ComposerFieldState extends State<_ComposerField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(_ComposerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) _controller.text = widget.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: 1,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: widget.hint,
        border: InputBorder.none,
      ),
    );
  }
}
