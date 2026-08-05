import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../auth/state_management/auth/auth_state.dart';
import '../../feature_flags/data/feature_flags_repository.dart';
import '../../feature_flags/data/feature_flags_snapshot.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../profile/data/profile_repository.dart';
import '../data/groups_repository.dart';
import '../models/group.dart';
import 'groups_events.dart';
import 'groups_state.dart';

/// App-wide holder of the user's groups (provided in `main.dart`, like
/// [AuthBloc] and `QuestionListsBloc`), so the home-screen cards, the group
/// screen and the feed all read one state and update together.
///
/// Groups are an authenticated feature, and the server enforces the `groups`
/// flag on every call — so the list is only requested once both a session and
/// the flag are there, and is dropped on sign-out. The flag is watched rather
/// than sampled: on login the flags are refreshed asynchronously, so it usually
/// arrives a moment *after* the session does.
///
/// Membership changes re-read the flags: a group can carry its own grants (the
/// group-subscription groundwork), so joining or leaving one may change what
/// the user is entitled to.
@injectable
class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  GroupsBloc(this._groups, this._profiles, this._authBloc, this._flags)
    : super(const GroupsState()) {
    on<GroupsStarted>(_onStarted);
    on<GroupsRefreshed>((event, emit) => _load(emit));
    on<GroupsSessionChanged>(_onSessionChanged);
    on<GroupsAvailabilityChanged>(_onAvailabilityChanged);
    on<GroupsUpdated>(
      (event, emit) => emit(state.copyWith(groups: event.groups)),
    );
    on<GroupInvitePreviewRequested>(_onInvitePreviewRequested);
    on<GroupInvitePreviewHandled>(
      (event, emit) =>
          emit(state.copyWith(invitePreview: null, previewToken: null)),
    );
    on<GroupCreationRequested>(_onCreationRequested);
    on<GroupJoinRequested>(_onJoinRequested);
    on<GroupLeaveRequested>(_onLeaveRequested);
    on<GroupsErrorShown>(
      (event, emit) => emit(state.copyWith(errorMessage: null)),
    );
    on<GroupOpenHandled>(
      (event, emit) => emit(state.copyWith(openGroupId: null)),
    );
  }

  final GroupsRepository _groups;
  final ProfileRepository _profiles;
  final AuthBloc _authBloc;

  /// Feature availability — the same instance `main()` bootstraps, resolved
  /// through `RegisterModule`.
  final FeatureFlagsRepository _flags;

  StreamSubscription<List<Group>>? _groupsSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<FeatureFlagsSnapshot>? _flagsSubscription;

  Future<void> _onStarted(
    GroupsStarted event,
    Emitter<GroupsState> emit,
  ) async {
    _groupsSubscription ??= _groups.changes.listen(
      (groups) => add(GroupsUpdated(groups)),
    );
    _authSubscription ??= _authBloc.stream.listen((auth) {
      if (auth.status == AuthStatus.unknown) return;
      add(GroupsSessionChanged(authenticated: auth.isAuthenticated));
    });
    _flagsSubscription ??= _flags.changes.listen(
      (snapshot) => add(
        GroupsAvailabilityChanged(
          enabled: snapshot.isEnabled(AppFeature.groups),
        ),
      ),
    );
    if (_authBloc.state.status != AuthStatus.unknown) {
      add(GroupsSessionChanged(authenticated: _authBloc.state.isAuthenticated));
    }
  }

  Future<void> _onSessionChanged(
    GroupsSessionChanged event,
    Emitter<GroupsState> emit,
  ) async {
    if (event.authenticated == state.authenticated) return;
    emit(state.copyWith(authenticated: event.authenticated));
    if (!event.authenticated) {
      _groups.onLoggedOut();
      emit(state.copyWith(loaded: false, profile: null));
      return;
    }
    await _load(emit);
  }

  Future<void> _onAvailabilityChanged(
    GroupsAvailabilityChanged event,
    Emitter<GroupsState> emit,
  ) async {
    if (event.enabled == state.featureEnabled) return;
    emit(state.copyWith(featureEnabled: event.enabled));
    if (event.enabled) {
      await _load(emit);
    } else {
      // The feature was switched off (locally or by the backend): forget the
      // list rather than keep showing cards nothing can act on.
      _groups.onLoggedOut();
      emit(state.copyWith(loaded: false));
    }
  }

  /// Load the profile and the groups. Both are needed before the first tap: the
  /// profile decides whether the display-name dialog has to come first.
  Future<void> _load(Emitter<GroupsState> emit) async {
    if (!state.authenticated || !state.featureEnabled || state.loading) return;
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final profile = await _profiles.myProfile();
      await _groups.refresh();
      if (emit.isDone) return;
      emit(state.copyWith(loading: false, loaded: true, profile: profile));
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(loading: false, errorMessage: e.toString()));
    }
  }

  /// Resolve an invite code so the user sees *which* group they are about to
  /// join. A code that is expired, revoked or unknown fails here — before
  /// anything is changed — and the server's message says which.
  Future<void> _onInvitePreviewRequested(
    GroupInvitePreviewRequested event,
    Emitter<GroupsState> emit,
  ) async {
    emit(state.copyWith(busy: true, errorMessage: null));
    try {
      final preview = await _groups.invitePreview(event.token);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          busy: false,
          invitePreview: preview,
          previewToken: event.token,
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreationRequested(
    GroupCreationRequested event,
    Emitter<GroupsState> emit,
  ) => _write(
    emit,
    event.displayNameToSet,
    () async => (await _groups.create(event.name)).id,
  );

  Future<void> _onJoinRequested(
    GroupJoinRequested event,
    Emitter<GroupsState> emit,
  ) => _write(
    emit,
    event.displayNameToSet,
    () async => (await _groups.joinByInvite(event.token)).id,
  );

  Future<void> _onLeaveRequested(
    GroupLeaveRequested event,
    Emitter<GroupsState> emit,
  ) => _write(emit, null, () async {
    await _groups.leave(event.groupId);
    return null;
  });

  /// Run one membership write: set the display name first when the user just
  /// typed one, then the call itself, then re-read the feature flags (a group's
  /// grants reach its members). The returned id is what the UI opens next, or
  /// `null` when there is nowhere to go.
  Future<void> _write(
    Emitter<GroupsState> emit,
    String? displayNameToSet,
    Future<String?> Function() action,
  ) async {
    emit(state.copyWith(busy: true, errorMessage: null));
    try {
      var profile = state.profile;
      if (displayNameToSet != null) {
        profile = await _profiles.setDisplayName(displayNameToSet);
      }
      final openGroupId = await action();
      await _flags.refreshFromBackend();
      if (emit.isDone) return;
      emit(
        state.copyWith(busy: false, profile: profile, openGroupId: openGroupId),
      );
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, errorMessage: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _groupsSubscription?.cancel();
    _authSubscription?.cancel();
    _flagsSubscription?.cancel();
    return super.close();
  }
}
