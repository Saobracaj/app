import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui_auth;
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart'
    as fb_ui_oauth_apple;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    as fb_ui_oauth_google;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../firebase_options.dart';
import '../../generated/locale_keys.g.dart';
import '../data/firebase_init.dart';
import '../data/graphql_client.dart';
import '../state_management/auth_cubit.dart';

/// Google / Apple sign-in buttons rendered with the `firebase_ui_auth`
/// [fb_ui_auth.OAuthProviderButton]s (same look as owncup). On a successful
/// Firebase sign-in it forwards the Firebase ID token to the back-end
/// `firebaseAuth` mutation ([AuthRepository.firebaseAuth]) and hands the session
/// to the [AuthCubit].
///
/// While the Firebase project isn't wired up yet (placeholder
/// `firebase_options.dart`, see [firebaseReady]) the buttons are hidden — run
/// `flutterfire configure` to enable them.
class SocialLogin extends StatefulWidget {
  const SocialLogin({super.key});

  @override
  State<SocialLogin> createState() => _SocialLoginState();
}

class _SocialLoginState extends State<SocialLogin> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Start from a clean Firebase session; the back-end session is authoritative.
    _firebaseSignOut();
  }

  Future<void> _firebaseSignOut() async {
    if (!firebaseReady) return;
    try {
      await fb_ui_auth.FirebaseUIAuth.signOut(context: context);
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _onAuthState(fb_ui_auth.AuthState authState) async {
    if (authState is! fb_ui_auth.SignedIn) return;
    final idToken = await authState.user?.getIdToken(true);
    if (idToken == null || !mounted) return;

    final cubit = context.read<AuthCubit>();
    final router = Routemaster.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final tokens = await cubit.repository.firebaseAuth(idToken);
      if (!mounted) return;
      if (tokens.authenticated) {
        await cubit.onAuthenticated();
        if (!mounted) return;
        router.pop();
      }
    } on GraphqlException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Drop the Firebase session regardless of the outcome.
      await _firebaseSignOut();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) return const SizedBox.shrink();

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
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else ...[
          fb_ui_auth.AuthStateListener<fb_ui_auth.OAuthController>(
            listener: (oldState, state, controller) {
              _onAuthState(state);
              return null;
            },
            child: fb_ui_auth.OAuthProviderButton(
              provider: fb_ui_oauth_google.GoogleProvider(clientId: _googleClientId),
            ),
          ),
          const SizedBox(height: 12),
          fb_ui_auth.AuthStateListener<fb_ui_auth.OAuthController>(
            listener: (oldState, state, controller) {
              _onAuthState(state);
              return null;
            },
            child: fb_ui_auth.OAuthProviderButton(
              provider: fb_ui_oauth_apple.AppleProvider(),
            ),
          ),
        ],
      ],
    );
  }

  String get _googleClientId {
    if (DefaultFirebaseOptions.currentPlatform == DefaultFirebaseOptions.ios) {
      return DefaultFirebaseOptions.ios.iosClientId ??
          DefaultFirebaseOptions.ios.appId;
    }
    return DefaultFirebaseOptions.currentPlatform.appId;
  }
}
