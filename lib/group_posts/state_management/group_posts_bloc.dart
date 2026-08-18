import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../chat/models/chat.dart';
import '../data/group_posts_repository.dart';
import 'group_posts_events.dart';
import 'group_posts_state.dart';

/// One group's wall: pages of history downwards, a composer at the bottom.
///
/// Unlike the feed there is no subscription of its own — a post is a feed event,
/// so the screen re-reads the head whenever the feed's live stream reports one
/// (see `GroupScreen`). Everything the composer holds lives here too: an
/// attachment is uploaded the moment it is picked, so sending a post is one
/// short mutation rather than a multi-megabyte wait.
@injectable
class GroupPostsBloc extends Bloc<GroupPostsBlocEvent, GroupPostsState> {
  GroupPostsBloc(this._posts, @factoryParam String groupId)
    : super(GroupPostsState(groupId: groupId)) {
    on<GroupPostsOpened>((event, emit) => _loadHead(emit, first: true));
    on<GroupPostsRefreshed>((event, emit) => _loadHead(emit));
    on<GroupPostsMoreRequested>(_onMore);
    on<GroupPostAttachPressed>(_onAttachPressed);
    on<GroupPostListAttached>(_onListAttached);
    on<GroupPostAttachmentRemoved>(_onAttachmentRemoved);
    on<GroupPostBodyChanged>(
      (event, emit) => emit(state.copyWith(body: event.body)),
    );
    on<GroupPostSubmitted>(_onSubmitted);
    on<GroupPostDeleted>(_onDeleted);
    on<GroupPostCommentsChanged>(_onCommentsChanged);
    on<GroupPostsErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final GroupPostsRepository _posts;

  /// How many posts one page holds. The server caps a page at 50.
  static const pageSize = 20;

  /// The server's own cap (20 MB); checked here so a huge file fails instantly
  /// instead of after a long upload.
  static const _maxAttachmentBytes = 20 * 1024 * 1024;

  Future<void> _loadHead(
    Emitter<GroupPostsState> emit, {
    bool first = false,
  }) async {
    emit(state.copyWith(loading: true));
    try {
      final page = await _posts.page(state.groupId, limit: pageSize);
      emit(
        state.copyWith(
          posts: page.posts,
          hasMore: page.hasMore,
          nextBefore: page.nextBefore,
          nextBeforeId: page.nextBeforeId,
          loading: false,
          loaded: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          // A refresh that fails leaves what is on screen readable; only the
          // very first read has nothing to fall back on.
          loaded: state.loaded || !first,
          errorMessage: '$e',
        ),
      );
    }
  }

  Future<void> _onMore(
    GroupPostsMoreRequested event,
    Emitter<GroupPostsState> emit,
  ) async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _posts.page(
        state.groupId,
        limit: pageSize,
        before: state.nextBefore,
        beforeId: state.nextBeforeId,
      );
      // Keyed by id: a post published while the reader was scrolling shifts the
      // window, and the same row must not appear twice.
      final seen = state.posts.map((p) => p.id).toSet();
      emit(
        state.copyWith(
          posts: [
            ...state.posts,
            ...page.posts.where((p) => !seen.contains(p.id)),
          ],
          hasMore: page.hasMore,
          nextBefore: page.nextBefore,
          nextBeforeId: page.nextBeforeId,
          loadingMore: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false, errorMessage: '$e'));
    }
  }

  /// Pick a file and upload it right away, exactly as the support chat does —
  /// the author sees the attachment before committing to the post, and sending
  /// is then one short mutation.
  Future<void> _onAttachPressed(
    GroupPostAttachPressed event,
    Emitter<GroupPostsState> emit,
  ) async {
    if (state.uploading) return;
    final XFile? file;
    try {
      file = await openFile();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
      return;
    }
    if (file == null) return;

    emit(state.copyWith(uploading: true));
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxAttachmentBytes) {
        emit(
          state.copyWith(
            uploading: false,
            errorMessage: 'support.attachmentTooLarge',
          ),
        );
        return;
      }
      // `XFile.mimeType` is null everywhere except the web, and the backend
      // decides what is a picture from what it is told — without the fallback
      // every screenshot from a phone would be filed away as a download.
      final mimeType = file.mimeType;
      final attachment = await _posts.uploadAttachment(
        groupId: state.groupId,
        bytes: bytes,
        fileName: file.name,
        contentType: mimeType == null || mimeType.isEmpty
            ? contentTypeForFileName(file.name)
            : mimeType,
      );
      emit(
        state.copyWith(
          pending: [...state.pending, attachment],
          uploading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(uploading: false, errorMessage: '$e'));
    }
  }

  void _onListAttached(
    GroupPostListAttached event,
    Emitter<GroupPostsState> emit,
  ) {
    if (state.pendingLists.any((l) => l.id == event.list.id)) return;
    emit(state.copyWith(pendingLists: [...state.pendingLists, event.list]));
  }

  void _onAttachmentRemoved(
    GroupPostAttachmentRemoved event,
    Emitter<GroupPostsState> emit,
  ) {
    emit(
      state.copyWith(
        pending: state.pending.where((a) => a.id != event.id).toList(),
        pendingLists: state.pendingLists
            .where((l) => l.id != event.id)
            .toList(),
      ),
    );
  }

  Future<void> _onSubmitted(
    GroupPostSubmitted event,
    Emitter<GroupPostsState> emit,
  ) async {
    if (!state.canSubmit) return;
    emit(state.copyWith(submitting: true));
    try {
      final post = await _posts.create(
        state.groupId,
        body: state.body.trim(),
        attachmentIds: state.pending.map((a) => a.id).toList(),
        // Automatic lists ("recent mistakes") are derived on the device and the
        // server knows nothing about them, so only real lists are shareable.
        questionListIds: state.pendingLists
            .where((l) => !l.isAuto)
            .map((l) => l.id)
            .toList(),
      );
      emit(
        state.copyWith(
          posts: [post, ...state.posts],
          body: '',
          pending: const [],
          pendingLists: const [],
          submitting: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: '$e'));
    }
  }

  Future<void> _onDeleted(
    GroupPostDeleted event,
    Emitter<GroupPostsState> emit,
  ) async {
    // Optimistic: the row goes now, and comes back if the server refuses.
    final previous = state.posts;
    emit(
      state.copyWith(
        posts: previous.where((p) => p.id != event.postId).toList(),
      ),
    );
    try {
      await _posts.deletePost(event.postId);
    } catch (e) {
      emit(state.copyWith(posts: previous, errorMessage: '$e'));
    }
  }

  void _onCommentsChanged(
    GroupPostCommentsChanged event,
    Emitter<GroupPostsState> emit,
  ) {
    emit(
      state.copyWith(
        posts: [
          for (final post in state.posts)
            if (post.id == event.postId)
              post.copyWith(
                commentsCount: (post.commentsCount + event.delta).clamp(
                  0,
                  1 << 31,
                ),
              )
            else
              post,
        ],
      ),
    );
  }
}
