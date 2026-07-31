import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart'
    as fb_ui_oauth_apple;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    as fb_ui_oauth_google;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../firebase_options.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/firebase_login/firebase_login_bloc.dart';
import '../state_management/firebase_login/firebase_login_events.dart';
import '../state_management/firebase_login/firebase_login_state.dart';

/// Google / Apple sign-in buttons rendered with the `firebase_ui_auth`
/// [fb_ui_auth.OAuthProviderButton]s (same look and flow as owncup). The buttons
/// are **always** available — Firebase is used only to obtain an OAuth ID token,
/// which [FirebaseLoginBloc] exchanges for our own session. Before every attempt
/// the Firebase session is cleared, so re-tapping never trips the
/// `provider-already-linked` error.
class SocialLogin extends StatelessWidget {
  const SocialLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FirebaseLoginBloc>(
      create: (providerContext) {
        // Start from a clean Firebase session; the back-end session is
        // authoritative.
        _firebaseSignOut(providerContext);
        return getIt<FirebaseLoginBloc>();
      },
      child: BlocConsumer<FirebaseLoginBloc, FirebaseLoginState>(
        listener: (context, state) {
          if (state.shouldLogOut) _firebaseSignOut(context);
          if (state.success) Routemaster.of(context).pop();
          final error = state.errorMessage;
          if (error != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error)));
          }
        },
        builder: (context, state) {
          if (state.isBusy) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            );
          }
          final bloc = context.read<FirebaseLoginBloc>();
          return Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(LocaleKeys.auth_or.tr()),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              fb_ui_auth.AuthStateListener<fb_ui_auth.OAuthController>(
                listener: (oldState, authState, controller) {
                  bloc.add(FirebaseAuthReceived(authState));
                  return null;
                },
                child: fb_ui_auth.OAuthProviderButton(
                  provider:
                      fb_ui_oauth_google.GoogleProvider(clientId: _googleClientId),
                ),
              ),
              const SizedBox(height: 12),
              fb_ui_auth.AuthStateListener<fb_ui_auth.OAuthController>(
                listener: (oldState, authState, controller) {
                  bloc.add(FirebaseAuthReceived(authState));
                  return null;
                },
                child: fb_ui_auth.OAuthProviderButton(
                  provider: fb_ui_oauth_apple.AppleProvider(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _firebaseSignOut(BuildContext context) async {
    try {
      await fb_ui_auth.FirebaseUIAuth.signOut(context: context);
    } catch (_) {
      // best-effort
    }
  }

  String get _googleClientId {
    if (DefaultFirebaseOptions.currentPlatform == DefaultFirebaseOptions.ios) {
      return DefaultFirebaseOptions.ios.iosClientId ??
          DefaultFirebaseOptions.ios.appId;
    }
    return DefaultFirebaseOptions.currentPlatform.appId;
  }
}
