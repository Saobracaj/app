// ignore_for_file: dead_code

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
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
import '../../generated/locale_keys.g.dart';
import '../data/firebase_init.dart';
import '../state_management/firebase_login/firebase_login_bloc.dart';
import '../state_management/firebase_login/firebase_login_events.dart';
import '../state_management/firebase_login/firebase_login_state.dart';
import 'error_field.dart';
import 'widgets/social_sign_in_buttons.dart';

/// Даёт всей странице авторизации доступ к [FirebaseLoginBloc]: сама секция
/// соц-входа ([SocialLogin]) рисуется по этому состоянию, а форма
/// логина/регистрации по нему же выключает свои поля и кнопки, пока идёт вход
/// через Google/Apple.
///
/// Здесь же живут one-shot эффекты блока: сброс Firebase-сессии и уход со
/// страницы после успеха.
class SocialLoginScope extends StatelessWidget {
  const SocialLoginScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FirebaseLoginBloc>(
      create: (providerContext) {
        // Start from a clean Firebase session; the back-end session is
        // authoritative.
        firebaseSignOut(providerContext);
        return getIt<FirebaseLoginBloc>();
      },
      child: BlocListener<FirebaseLoginBloc, FirebaseLoginState>(
        listener: (context, state) {
          if (state.shouldLogOut) firebaseSignOut(context);
          if (state.success) Routemaster.of(context).pop();
        },
        child: child,
      ),
    );
  }
}

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
///
/// Пока идёт вход, спиннер крутится только на нажатой кнопке — вторая просто
/// выключается; ошибка показывается инлайново под кнопками.
/// Требует [SocialLoginScope] выше по дереву.
class SocialLogin extends StatelessWidget {
  const SocialLogin({super.key, this.enabled = true});

  /// `false` — страница занята чем-то другим (например, входом по паролю), и
  /// кнопки соц-входа нажимать нельзя.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FirebaseLoginBloc, FirebaseLoginState>(
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
            for (final button in _providerButtons(bloc, state)) button,
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              ErrorField(message: state.errorMessage),
            ],
          ],
        );
      },
    );
  }

  /// Which social buttons to show, per platform:
  /// - **web**: Google + Apple (Apple's web redirect flow works there);
  /// - **iOS**: Apple only (native Sign in with Apple);
  /// - **Android**: Google only — Apple's federated flow on Android goes through
  ///   Firebase's `__/auth/handler` web page and reliably fails with
  ///   `missing initial state` (lost `sessionStorage` across the redirect), so it
  ///   is intentionally not offered here.
  List<Widget> _providerButtons(
    FirebaseLoginBloc bloc,
    FirebaseLoginState state,
  ) {
    Widget google() =>
        _GoogleButton(bloc: bloc, state: state, pageEnabled: enabled);
    Widget apple() =>
        _AppleButton(bloc: bloc, state: state, pageEnabled: enabled);

    if (kIsWeb) {
      // На web кнопки дёргают блок напрямую, без AuthFlowBuilder: вход ведёт
      // сам блок через signInWithPopup (см. FirebaseLoginBloc._webSignIn), а
      // конструирование GoogleProvider здесь роняло страницу — GoogleSignIn на
      // web инициализирует GIS SDK прямо в конструкторе и без client_id кидает
      // необработанное исключение при каждом rebuild.
      VoidCallback? onPressed(SocialAuthProvider provider) =>
          (!enabled || state.isBusy)
              ? null
              : () => bloc.add(SocialSignInPressed(provider));
      return [
        GoogleSignInButton(
          onPressed: onPressed(SocialAuthProvider.google),
          busy: state.isBusyWith(SocialAuthProvider.google),
        ),
        const SizedBox(height: 12),
        AppleSignInButton(
          onPressed: onPressed(SocialAuthProvider.apple),
          busy: state.isBusyWith(SocialAuthProvider.apple),
        ),
      ];
    }

    // all the buttons are temporarily enabled for all platforms for testing purposes
    if (true) {
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
}

/// Сбрасывает Firebase-сессию (best-effort): нашей сессией управляет бэкенд, а
/// «чистая» Firebase-сессия нужна, чтобы повторный тап не пытался залинковать
/// уже прилинкованный провайдер.
Future<void> firebaseSignOut(BuildContext context) async {
  try {
    if (kIsWeb) {
      // FirebaseUIAuth.signOut дёргает logOutProvider каждого провайдера, а
      // GoogleProvider в браузере под macOS принимает web за нативную
      // платформу и зовёт google_sign_in без client_id — непойманное
      // исключение прямо при открытии страницы. На web достаточно сбросить
      // самого пользователя Firebase.
      await fba.FirebaseAuth.instance.signOut();
    } else {
      await fb_ui_auth.FirebaseUIAuth.signOut(context: context);
    }
  } catch (_) {
    // best-effort
  }
}

/// Wires an OAuth [provider] to the [bloc] and renders [child] (a brand button)
/// with the flow's controller and busy state. [AuthStateListener] must sit above
/// [AuthFlowBuilder] so its `AuthStateTransition` notifications bubble up into
/// the listener and get forwarded to the bloc as [FirebaseAuthReceived].
class _OAuthButtonScaffold extends StatelessWidget {
  const _OAuthButtonScaffold({
    required this.bloc,
    required this.state,
    required this.socialProvider,
    required this.pageEnabled,
    required this.provider,
    required this.builder,
  });

  final FirebaseLoginBloc bloc;
  final FirebaseLoginState state;
  final SocialAuthProvider socialProvider;
  final bool pageEnabled;
  final fb_ui_oauth.OAuthProvider provider;

  /// `onPressed == null` — кнопка выключена; `busy` — на ней спиннер.
  final Widget Function(VoidCallback? onPressed, bool busy) builder;

  @override
  Widget build(BuildContext context) {
    return fb_ui_auth.AuthStateListener<fb_ui_auth.OAuthController>(
      listener: (oldState, authState, controller) {
        bloc.add(FirebaseAuthReceived(authState));
        return null;
      },
      child: fb_ui_auth.AuthFlowBuilder<fb_ui_auth.OAuthController>(
        provider: provider,
        builder: (context, authState, controller, child) {
          // Firebase-side sign-in is in flight, or the bloc is exchanging the
          // ID token for our session: keep the tapped button spinning either
          // way. Обе проверки относятся только к этому провайдеру, поэтому
          // спиннер никогда не появляется на двух кнопках сразу.
          final busy = authState is fb_ui_auth.SigningIn ||
              authState is fb_ui_auth.CredentialReceived ||
              state.isBusyWith(socialProvider);
          final locked = busy || state.isBusy || !pageEnabled;
          return builder(
            locked
                ? null
                : () {
                    bloc.add(SocialSignInPressed(socialProvider));
                    // На web вход ведёт сам блок (signInWithPopup): флоу
                    // firebase_ui в wasm-сборке уходит в нативную ветку и
                    // ломается (см. FirebaseLoginBloc._webSignIn).
                    if (!kIsWeb) {
                      controller.signIn(Theme.of(context).platform);
                    }
                  },
            busy,
          );
        },
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.bloc,
    required this.state,
    required this.pageEnabled,
  });

  final FirebaseLoginBloc bloc;
  final FirebaseLoginState state;
  final bool pageEnabled;

  @override
  Widget build(BuildContext context) {
    return _OAuthButtonScaffold(
      bloc: bloc,
      state: state,
      socialProvider: SocialAuthProvider.google,
      pageEnabled: pageEnabled,
      provider: fb_ui_oauth_google.GoogleProvider(
        clientId: googleOAuthClientId,
      ),
      builder: (onPressed, busy) =>
          GoogleSignInButton(onPressed: onPressed, busy: busy),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({
    required this.bloc,
    required this.state,
    required this.pageEnabled,
  });

  final FirebaseLoginBloc bloc;
  final FirebaseLoginState state;
  final bool pageEnabled;

  @override
  Widget build(BuildContext context) {
    return _OAuthButtonScaffold(
      bloc: bloc,
      state: state,
      socialProvider: SocialAuthProvider.apple,
      pageEnabled: pageEnabled,
      provider: fb_ui_oauth_apple.AppleProvider(),
      builder: (onPressed, busy) =>
          AppleSignInButton(onPressed: onPressed, busy: busy),
    );
  }
}
