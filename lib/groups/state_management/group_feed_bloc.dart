import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/groups_repository.dart';
import '../models/group_event.dart';
import '../models/group_feed_update.dart';
import 'group_feed_events.dart';
import 'group_feed_state.dart';

/// One group's activity feed: pages of history downwards, live events from the
/// top.
///
/// The two sources have to agree on one list, and they can overlap — an event
/// pushed over the socket may already be on the first page, and a sync of older
/// results arrives in *arrival* order rather than in the order it belongs in.
/// So nothing is appended blindly: events are keyed by id and placed by their
/// `(occurredAt, id)`, exactly the order the server pages in. An event older
/// than the oldest one on screen is dropped while there is still unread history
/// below — it belongs to a page that has not been loaded yet, and would show up
/// twice once it is.
@injectable
class GroupFeedBloc extends Bloc<GroupFeedBlocEvent, GroupFeedState> {
  GroupFeedBloc(this._groups, @factoryParam String groupId)
    : super(
        GroupFeedState(
          groupId: groupId,
          // The home screen has already loaded the user's groups by the time one
          // of them can be opened, so the title is known up front.
          groupName: _nameOf(_groups, groupId),
        ),
      ) {
    on<GroupFeedOpened>(_onOpened);
    on<GroupFeedRefreshed>((event, emit) => _loadHead(emit));
    on<GroupFeedMoreRequested>(_onMore);
    on<GroupFeedEventArrived>(_onEventArrived);
    on<GroupFeedLiveChanged>(_onLiveChanged);
    on<GroupFeedErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
  }

  final GroupsRepository _groups;

  StreamSubscription<GroupFeedUpdate>? _live;

  /// How many events one page holds. The server caps a page at 50.
  static const pageSize = 20;

  /// How many new lines one "load more" tries to put on screen. A server page
  /// is not a screenful: abandoned runs, unknown kinds and blocks that no longer
  /// exist are filtered out, and a page can lose all of its events that way.
  static const _visibleTarget = pageSize;

  /// The ceiling on how many pages one "load more" reads while looking for those
  /// lines — a group where almost everything is filtered out must not turn one
  /// scroll into a march through the whole history.
  static const _maxPagesPerRequest = 5;

  @override
  Future<void> close() {
    _live?.cancel();
    return super.close();
  }

  Future<void> _onOpened(
    GroupFeedOpened event,
    Emitter<GroupFeedState> emit,
  ) async {
    _listen();
    await _loadHead(emit, first: true);
  }

  /// Go live. Failures here are silent on purpose: a feed that cannot subscribe
  /// still reads and pages perfectly well, and the screen says so with the
  /// "live" indicator rather than with an error the reader can do nothing about.
  void _listen() {
    _live ??= _groups
        .feedChanges(state.groupId)
        .listen(
          (update) {
            switch (update) {
              case GroupFeedEventReceived(:final event):
                add(GroupFeedEventArrived(event));
              case GroupFeedResumed(:final firstConnect):
                add(
                  GroupFeedLiveChanged(live: true, missedEvents: !firstConnect),
                );
              case GroupFeedInterrupted():
                add(
                  const GroupFeedLiveChanged(live: false, missedEvents: false),
                );
            }
          },
          onError: (_) =>
              add(const GroupFeedLiveChanged(live: false, missedEvents: false)),
          onDone: () =>
              add(const GroupFeedLiveChanged(live: false, missedEvents: false)),
        );
  }

  /// Read the newest page and fold it into what is on screen. Used for the first
  /// load, for pull-to-refresh and after a reconnect — in every case the point
  /// is the top of the list, so the cursor is left alone.
  Future<void> _loadHead(
    Emitter<GroupFeedState> emit, {
    bool first = false,
  }) async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final page = await _groups.feed(state.groupId, limit: pageSize);
      if (emit.isDone) return;
      // On the very first read the page *is* the list, cursor included; later
      // reads only top it up, so the cursor to the unread history stays.
      emit(
        first || state.events.isEmpty
            ? state.copyWith(
                loading: false,
                loaded: true,
                events: page.events.where((e) => e.isVisibleInFeed).toList(),
                hasMore: page.hasMore,
                nextBefore: page.nextBefore,
                nextBeforeId: page.nextBeforeId,
              )
            : state.copyWith(
                loading: false,
                loaded: true,
                events: _mergeHead(page.events),
              ),
      );
      // The whole page was filtered out while there is history behind it: say
      // "nothing has happened here" and the reader would never see the events
      // that have. Dig for them instead.
      if (state.events.isEmpty && state.hasMore) {
        add(const GroupFeedMoreRequested());
      }
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(loading: false, errorMessage: e.toString()));
    }
  }

  /// Read history until there is something new to show.
  ///
  /// Reading exactly one page is not enough: the page may be filtered away to
  /// nothing (see [GroupEvent.isVisibleInFeed]) and leave the list as short as it
  /// was — with more history behind it. On a list too short to scroll that was
  /// the end of it: only scrolling asks for the next page, so the spinner at the
  /// bottom stayed on screen forever. So one request keeps reading, up to
  /// [_maxPagesPerRequest] pages, until it has [_visibleTarget] lines to add or
  /// runs out of history.
  Future<void> _onMore(
    GroupFeedMoreRequested event,
    Emitter<GroupFeedState> emit,
  ) async {
    if (!state.hasMore || state.loadingMore || state.loading) return;
    emit(state.copyWith(loadingMore: true, errorMessage: null));
    final events = [...state.events];
    final known = events.map((e) => e.id).toSet();
    var before = state.nextBefore;
    var beforeId = state.nextBeforeId;
    var hasMore = state.hasMore;
    var added = 0;
    var pagesRead = 0;
    try {
      while (hasMore &&
          added < _visibleTarget &&
          pagesRead < _maxPagesPerRequest) {
        pagesRead++;
        final page = await _groups.feed(
          state.groupId,
          limit: pageSize,
          before: before,
          beforeId: beforeId,
        );
        if (emit.isDone) return;
        for (final older in page.events) {
          if (!older.isVisibleInFeed || !known.add(older.id)) continue;
          events.add(older);
          added++;
        }
        // A cursor that does not move means the next read would return this very
        // page again — better to call it the end than to loop over it.
        final stalled =
            page.nextBefore == null ||
            (page.nextBefore == before && page.nextBeforeId == beforeId);
        hasMore = page.hasMore && !stalled;
        before = page.nextBefore;
        beforeId = page.nextBeforeId;
      }
      emit(
        state.copyWith(
          loadingMore: false,
          events: events,
          hasMore: hasMore,
          nextBefore: before,
          nextBeforeId: beforeId,
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
      // Прочитанное до сбоя остаётся на экране вместе со сдвинутым курсором:
      // иначе следующая попытка пошла бы с самого начала и снова уткнулась бы в
      // ту же страницу.
      emit(
        state.copyWith(
          loadingMore: false,
          events: events,
          hasMore: hasMore,
          nextBefore: before,
          nextBeforeId: beforeId,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onEventArrived(
    GroupFeedEventArrived event,
    Emitter<GroupFeedState> emit,
  ) {
    final merged = _mergeHead([event.event]);
    if (merged.length == state.events.length) return;
    emit(state.copyWith(events: merged, loaded: true));
  }

  Future<void> _onLiveChanged(
    GroupFeedLiveChanged event,
    Emitter<GroupFeedState> emit,
  ) async {
    emit(state.copyWith(live: event.live));
    // A reconnect means the socket was down for a while, and the server keeps no
    // backlog — re-read the head rather than leave a gap.
    if (event.missedEvents && state.loaded) await _loadHead(emit);
  }

  /// Place [incoming] into the loaded list by `(occurredAt, id)`, dropping
  /// duplicates and anything that belongs to a page still unread below.
  List<GroupEvent> _mergeHead(Iterable<GroupEvent> incoming) {
    final oldest = state.oldest;
    final byId = {for (final event in state.events) event.id: event};
    for (final event in incoming) {
      if (!event.isVisibleInFeed || byId.containsKey(event.id)) continue;
      if (state.hasMore && oldest != null && _isOlder(event, oldest)) continue;
      byId[event.id] = event;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = b.occurredAt.compareTo(a.occurredAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return merged;
  }

  static String _nameOf(GroupsRepository groups, String groupId) {
    for (final group in groups.groups) {
      if (group.id == groupId) return group.name;
    }
    return '';
  }

  static bool _isOlder(GroupEvent event, GroupEvent than) {
    final byTime = event.occurredAt.compareTo(than.occurredAt);
    return byTime != 0 ? byTime < 0 : event.id.compareTo(than.id) < 0;
  }
}
