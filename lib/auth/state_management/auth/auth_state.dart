import 'package:flutter/foundation.dart';

import '../../data/auth_status.dart';
import '../../models/viewer.dart';

export '../../data/auth_status.dart';

/// App-wide authentication state. Also carries the locally stored notification
/// preferences so the settings screen can reflect them without an extra query.
@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.viewer,
    this.emailNotifications = true,
    this.pushNotifications = true,
  });

  final AuthStatus status;
  final Viewer? viewer;
  final bool emailNotifications;
  final bool pushNotifications;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    Viewer? viewer,
    bool clearViewer = false,
    bool? emailNotifications,
    bool? pushNotifications,
  }) => AuthState(
    status: status ?? this.status,
    viewer: clearViewer ? null : (viewer ?? this.viewer),
    emailNotifications: emailNotifications ?? this.emailNotifications,
    pushNotifications: pushNotifications ?? this.pushNotifications,
  );
}
