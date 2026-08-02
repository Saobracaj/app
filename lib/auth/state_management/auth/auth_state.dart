import 'package:flutter/foundation.dart';

import '../../data/auth_status.dart';
import '../../models/viewer.dart';

export '../../data/auth_status.dart';

/// App-wide authentication state. Notification preferences live in their own
/// feature ([NotificationsBloc]); this only carries the session.
@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.viewer,
  });

  final AuthStatus status;
  final Viewer? viewer;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    Viewer? viewer,
    bool clearViewer = false,
  }) => AuthState(
    status: status ?? this.status,
    viewer: clearViewer ? null : (viewer ?? this.viewer),
  );
}
