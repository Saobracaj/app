import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../generated/locale_keys.g.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/graphql_client.dart';
import '../../auth/state_management/auth/auth_bloc.dart';
import '../../notifications/data/notification_permissions.dart';
import '../../profile/data/profile_repository.dart';
import '../data/public_comments_repository.dart';
import '../models/public_comment.dart';
import 'comments_events.dart';
import 'comments_state.dart';

/// Drives the public-comments panel for a single question.
///
/// Reads are public (sent authenticated only when a session exists, to populate
/// the viewer-relative flags). Likes are **optimistic**: the UI flips
/// immediately and rolls back if the request fails. Writes (post/reply/delete)
/// refetch the first page so the server-side ordering (by likes) stays correct.
///
/// The backend also offers a realtime `questionCommentsChanged` subscription;
/// the HTTP-only [GraphqlClient] can't consume it yet, so this Bloc refreshes
/// after its own mutations instead (true realtime is a follow-up).
@injectable
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc(
    this._comments,
    this._profiles,
    this._authBloc,
    this._authRepo,
    this._permissions,
    @factoryParam this.questionId,
    @factoryParam this.threadId,
  ) : super(const CommentsState()) {
    on<CommentsStarted>(_onStarted);
    on<CommentsRefreshed>(_onRefreshed);
    on<CommentsLoadMore>(_onLoadMore);
    on<CommentSubmitted>(_onSubmitted);
    on<CommentDeleted>(_onDeleted);
    on<CommentLikeToggled>(_onLikeToggled);
    on<CommentSubscriptionToggled>(_onSubscriptionToggled);
    on<CommentSubscribeAccepted>(_onSubscribeAccepted);
    on<SubscriptionPromptDismissed>(_onPromptDismissed);
    on<RepliesExpanded>(_onRepliesExpanded);
    on<ReplyFocusRequested>(_onReplyFocusRequested);
    on<ReplyTargetCleared>(_onReplyTargetCleared);
    on<CommentReported>(_onReported);
  }

  final PublicCommentsRepository _comments;
  final ProfileRepository _profiles;
  final AuthBloc _authBloc;
  final AuthRepository _authRepo;
  final NotificationPermissions _permissions;
  final int questionId;

  /// Deep-link target: a top-level comment to expand ("show previous" replies)
  /// once the first page has loaded, so the linked thread is fully visible.
  final String? threadId;

  /// SharedPreferences key mirroring `NotificationsBloc` so enabling push here
  /// (after the user subscribes to replies) stays in sync with the settings
  /// screen's toggle.
  static const _pushNotifKey = 'notif_push_enabled';

  bool get _isAuthenticated => _authBloc.state.isAuthenticated;

  Future<void> _onStarted(
    CommentsStarted event,
    Emitter<CommentsState> emit,
  ) async {
    final authed = _isAuthenticated;
    emit(
      state.copyWith(
        isAuthenticated: authed,
        viewerId: _authBloc.state.viewer?.id,
      ),
    );
    if (authed) {
      try {
        emit(state.copyWith(profile: await _profiles.myProfile()));
      } catch (_) {
        // best-effort; the composer just stays hidden until it loads.
      }
    }
    await _loadFirstPage(emit);
    // Deep link: reveal the linked thread's older replies.
    if (threadId != null) {
      emit(
        state.copyWith(expandedThreads: {...state.expandedThreads, threadId!}),
      );
    }
  }

  Future<void> _onRefreshed(
    CommentsRefreshed event,
    Emitter<CommentsState> emit,
  ) => _loadFirstPage(emit);

  Future<void> _loadFirstPage(Emitter<CommentsState> emit) async {
    try {
      final page = await _comments.questionComments(
        questionId,
        offset: 0,
        authenticated: _isAuthenticated,
      );
      emit(
        state.copyWith(
          loading: false,
          comments: page.nodes,
          totalCount: page.totalCount,
          hasNextPage: page.hasNextPage,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onLoadMore(
    CommentsLoadMore event,
    Emitter<CommentsState> emit,
  ) async {
    if (state.loadingMore || !state.hasNextPage) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _comments.questionComments(
        questionId,
        offset: state.comments.length,
        authenticated: _isAuthenticated,
      );
      emit(
        state.copyWith(
          loadingMore: false,
          comments: [...state.comments, ...page.nodes],
          totalCount: page.totalCount,
          hasNextPage: page.hasNextPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingMore: false, errorMessage: _message(e)));
    }
  }

  Future<void> _onSubmitted(
    CommentSubmitted event,
    Emitter<CommentsState> emit,
  ) async {
    emit(state.copyWith(submitting: true, errorMessage: null));

    // The user entered a display name in the pre-comment dialog — persist it
    // first (the backend re-validates and may reject it).
    if (event.displayNameToSet != null) {
      try {
        final profile = await _profiles.setDisplayName(event.displayNameToSet!);
        emit(state.copyWith(profile: profile));
      } catch (e) {
        emit(state.copyWith(submitting: false, errorMessage: _message(e)));
        return;
      }
    }

    try {
      final created = await _comments.addComment(
        questionId: questionId,
        parentId: event.parentId,
        body: event.body,
      );
      // Reveal the thread the reply landed in so the new reply is visible, and
      // clear the pinned composer's reply target — it has been consumed.
      final expanded = event.parentId == null
          ? state.expandedThreads
          : {...state.expandedThreads, event.parentId!};
      emit(
        state.copyWith(
          submitting: false,
          expandedThreads: expanded,
          replyFocusTarget: null,
        ),
      );
      await _loadFirstPage(emit);
      // Reply-subscription handling: only bother the user with the offer dialog
      // when they have no reply subscription set up yet. If they already
      // enabled push (i.e. subscribed to some thread before), just subscribe to
      // this thread silently and post; if they are already subscribed to this
      // thread, do nothing.
      if (!created.subscribedByMe) {
        final prefs = await SharedPreferences.getInstance();
        final alreadyOptedIn = prefs.getBool(_pushNotifKey) == true;
        if (alreadyOptedIn) {
          await _subscribeSilently(created, emit);
        } else {
          emit(state.copyWith(subscriptionPromptFor: created));
        }
      }
    } catch (e) {
      emit(state.copyWith(submitting: false, errorMessage: _message(e)));
    }
  }

  void _onPromptDismissed(
    SubscriptionPromptDismissed event,
    Emitter<CommentsState> emit,
  ) {
    emit(state.copyWith(subscriptionPromptFor: null));
  }

  /// The user accepted the reply-subscription offer: make sure push is allowed
  /// and enabled, then subscribe to the thread (the backend resolves the id to
  /// its top-level thread).
  Future<void> _onSubscribeAccepted(
    CommentSubscribeAccepted event,
    Emitter<CommentsState> emit,
  ) async {
    emit(state.copyWith(subscriptionPromptFor: null));
    final id = event.comment.id;

    // Optimistically reflect the subscription on the (top-level) comment.
    final topLevelId = event.comment.parentId ?? id;
    emit(
      state.copyWith(
        comments: _updateOne(
          state.comments,
          topLevelId,
          (c) => c.copyWith(subscribedByMe: true),
        ),
      ),
    );

    // Ensure the OS lets us deliver replies, and enable the app-level push
    // preference if permission is (now) granted — best-effort throughout.
    try {
      var status = await _permissions.status();
      if (!status.granted && !status.permanentlyDenied) {
        status = await _permissions.request();
      } else if (status.permanentlyDenied) {
        await _permissions.openSettings();
      }
      if (status.granted) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool(_pushNotifKey) != true) {
          await prefs.setBool(_pushNotifKey, true);
          if (_isAuthenticated) {
            try {
              await _authRepo.registerDevice(platform: _platform());
              await _authRepo.setDevicePushEnabled(true);
            } catch (_) {
              // Requires a configured FCM token to fully take effect.
            }
          }
        }
      }
    } catch (_) {
      // Permission plumbing is best-effort; the server subscription is what
      // actually matters and is attempted next.
    }

    try {
      await _comments.setCommentSubscription(id, true);
    } catch (_) {
      // Roll the optimistic flag back on failure.
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            topLevelId,
            (c) => c.copyWith(subscribedByMe: false),
          ),
        ),
      );
    }
  }

  String _platform() => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<void> _onDeleted(
    CommentDeleted event,
    Emitter<CommentsState> emit,
  ) async {
    try {
      await _comments.deleteComment(event.id);
      await _loadFirstPage(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: _message(e)));
    }
  }

  Future<void> _onLikeToggled(
    CommentLikeToggled event,
    Emitter<CommentsState> emit,
  ) async {
    final original = event.comment;
    final liked = !original.likedByMe;
    final delta = liked ? 1 : -1;

    // Optimistic: flip and adjust the count right away.
    emit(
      state.copyWith(
        comments: _updateOne(
          state.comments,
          original.id,
          (c) => c.copyWith(
            likedByMe: liked,
            likesCount: (c.likesCount + delta).clamp(0, 1 << 31),
          ),
        ),
      ),
    );

    try {
      final server = liked
          ? await _comments.likeComment(original.id)
          : await _comments.unlikeComment(original.id);
      // Reconcile the count with the server (without touching replies).
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            original.id,
            (c) => c.copyWith(
              likedByMe: server.likedByMe,
              likesCount: server.likesCount,
            ),
          ),
        ),
      );
    } catch (_) {
      // Roll back to the pre-tap values.
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            original.id,
            (c) => c.copyWith(
              likedByMe: original.likedByMe,
              likesCount: original.likesCount,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _onSubscriptionToggled(
    CommentSubscriptionToggled event,
    Emitter<CommentsState> emit,
  ) async {
    final id = event.comment.id;
    emit(
      state.copyWith(
        comments: _updateOne(
          state.comments,
          id,
          (c) => c.copyWith(subscribedByMe: event.subscribed),
        ),
      ),
    );
    try {
      await _comments.setCommentSubscription(id, event.subscribed);
    } catch (_) {
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            id,
            (c) => c.copyWith(subscribedByMe: !event.subscribed),
          ),
        ),
      );
    }
  }

  void _onRepliesExpanded(RepliesExpanded event, Emitter<CommentsState> emit) {
    emit(
      state.copyWith(
        expandedThreads: {...state.expandedThreads, event.topLevelId},
      ),
    );
  }

  void _onReplyFocusRequested(
    ReplyFocusRequested event,
    Emitter<CommentsState> emit,
  ) {
    emit(
      state.copyWith(
        replyFocusTarget: event.topLevelId,
        replyFocusRequestId: state.replyFocusRequestId + 1,
      ),
    );
  }

  void _onReplyTargetCleared(
    ReplyTargetCleared event,
    Emitter<CommentsState> emit,
  ) {
    emit(state.copyWith(replyFocusTarget: null));
  }

  void _onReported(CommentReported event, Emitter<CommentsState> emit) {
    emit(state.copyWith(reportedIds: {...state.reportedIds, event.id}));
  }

  /// Subscribe to [created]'s thread without prompting (used when the user has
  /// already opted into reply notifications) and reflect it optimistically.
  Future<void> _subscribeSilently(
    PublicComment created,
    Emitter<CommentsState> emit,
  ) async {
    final topLevelId = created.parentId ?? created.id;
    emit(
      state.copyWith(
        comments: _updateOne(
          state.comments,
          topLevelId,
          (c) => c.copyWith(subscribedByMe: true),
        ),
      ),
    );
    try {
      await _comments.setCommentSubscription(created.id, true);
    } catch (_) {
      emit(
        state.copyWith(
          comments: _updateOne(
            state.comments,
            topLevelId,
            (c) => c.copyWith(subscribedByMe: false),
          ),
        ),
      );
    }
  }

  /// Apply [fn] to the comment with [id], whether it is top-level or a reply,
  /// returning a new list (replies are searched one level deep — the tree is at
  /// most two deep).
  List<PublicComment> _updateOne(
    List<PublicComment> list,
    String id,
    PublicComment Function(PublicComment) fn,
  ) {
    return [
      for (final c in list)
        if (c.id == id)
          fn(c)
        else if (c.replies.any((r) => r.id == id))
          c.copyWith(
            replies: [
              for (final r in c.replies)
                if (r.id == id) fn(r) else r,
            ],
          )
        else
          c,
    ];
  }

  String _message(Object e) => e is GraphqlException
      ? e.message
      : LocaleKeys.comments_loadError.tr();
}
