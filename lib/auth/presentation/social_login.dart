// ignore_for_file: dead_code

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;
import 'package:firebase_ui_oauth/firebase_ui_oauth.dart' as fb_ui_oauth;
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart'
    as fb_ui_oauth_apple;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    as fb_ui_oauth_google;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../firebase_options.dart';
import '../../generated/locale_keys.g.dart';
import '../state_management/firebase_login/firebase_login_bloc.dart';
import '../state_management/firebase_login/firebase_login_events.dart';
import '../state_management/firebase_login/firebase_login_state.dart';
import 'widgets/social_sign_in_buttons.dart';

/// Google / Apple sign-in section. The buttons are our own brand-compliant,
/// theme-aware widgets ([GoogleSignInButton] / [AppleSignInButton]), but the
/// OAuth machinery is still `firebase_ui_auth`'s: each button is driven by an
/// [fb_ui_auth.AuthFlowBuilder] that exposes the [fb_ui_auth.OAuthController]
/// (to start the flow) and the current [fb_ui_auth.AuthState] (to show a
/// spinner), and an [fb_ui_auth.AuthStateListener] forwards every transition to
/// [FirebaseLoginBloc].
///
/// Firebase is used only to obtain an OAuth ID token, which the bloc exchanges
/// for our own session. Before every attempt the Firebase session is cleared,
/// so re-tapping never trips the `provider-already-linked` error.
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
              for (final button in _providerButtons(bloc, state.isBusy))
                button,
            ],
          );
        },
      ),
    );
  }

  /// Which social buttons to show, per platform:
  /// - **web**: Google + Apple (Apple's web redirect flow works there);
  /// - **iOS**: Apple only (native Sign in with Apple);
  /// - **Android**: Google only — Apple's federated flow on Android goes through
  ///   Firebase's `__/auth/handler` web page and reliably fails with
  ///   `missing initial state` (lost `sessionStorage` across the redirect), so it
  ///   is intentionally not offered here.
  List<Widget> _providerButtons(FirebaseLoginBloc bloc, bool busy) {
    Widget google() => _GoogleButton(bloc: bloc, blocBusy: busy);
    Widget apple() => _AppleButton(bloc: bloc, blocBusy: busy);

    // all the buttons are temporarily enabled for all platforms for testing purposes
    if (true || kIsWeb) {
      return [google(), const SizedBox(height: 12), apple()];
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return [apple()];
      case TargetPlatform.android:
        return [google()];
      default:
        // Desktop / other: offer both.
        return [google(), const SizedBox(height: 12), apple()];
    }
  }

  Future<void> _firebaseSignOut(BuildContext context) async {
    try {
      await fb_ui_auth.FirebaseUIAuth.signOut(context: context);
    } catch (_) {
      // best-effort
    }
  }
}

/// Wires an OAuth [provider] to the [bloc] and renders [child] (a brand button)
/// with the flow's controller and busy state. [AuthStateListener] must sit above
/// [AuthFlowBuilder] so its `AuthStateTransition` notifications bubble up into
/// the listener and get forwarded to the bloc as [FirebaseAuthReceived].
class _OAuthButtonScaffold extends StatelessWidget {
  const _OAuthButtonScaffold({
    required this.bloc,
    required this.provider,
    required this.blocBusy,
    required this.builder,
  });

  final FirebaseLoginBloc bloc;
  final fb_ui_oauth.OAuthProvider provider;
  final bool blocBusy;
  final Widget Function(VoidCallback onPressed, bool busy) builder;

  @override
  Widget build(BuildContext context) {
    return fb_ui_auth.AuthStateListener<fb_ui_auth.OAuthController>(
      listener: (oldState, authState, controller) {
        bloc.add(FirebaseAuthReceived(authState));
        return null;
      },
      child: fb_ui_auth.AuthFlowBuilder<fb_ui_auth.OAuthController>(
        provider: provider,
        builder: (context, state, controller, child) {
          // Firebase-side sign-in is in flight, or the bloc is exchanging the
          // ID token for our session: keep the tapped button spinning either way.
          final signingIn = state is fb_ui_auth.SigningIn ||
              state is fb_ui_auth.CredentialReceived;
          return builder(
            () => controller.signIn(Theme.of(context).platform),
            signingIn || blocBusy,
          );
        },
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.bloc, required this.blocBusy});

  final FirebaseLoginBloc bloc;
  final bool blocBusy;

  @override
  Widget build(BuildContext context) {
    return _OAuthButtonScaffold(
      bloc: bloc,
      blocBusy: blocBusy,
      provider: fb_ui_oauth_google.GoogleProvider(clientId: _googleClientId),
      builder: (onPressed, busy) =>
          GoogleSignInButton(onPressed: onPressed, busy: busy),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.bloc, required this.blocBusy});

  final FirebaseLoginBloc bloc;
  final bool blocBusy;

  @override
  Widget build(BuildContext context) {
    return _OAuthButtonScaffold(
      bloc: bloc,
      blocBusy: blocBusy,
      provider: fb_ui_oauth_apple.AppleProvider(),
      builder: (onPressed, busy) =>
          AppleSignInButton(onPressed: onPressed, busy: busy),
    );
  }
}

String get _googleClientId {
  if (DefaultFirebaseOptions.currentPlatform == DefaultFirebaseOptions.ios) {
    return DefaultFirebaseOptions.ios.iosClientId ??
        DefaultFirebaseOptions.ios.appId;
  }
  return DefaultFirebaseOptions.currentPlatform.appId;
}
