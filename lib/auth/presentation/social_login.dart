import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';

/// Google / Apple sign-in buttons.
///
/// The back-end already accepts a Firebase ID token via the `firebaseAuth`
/// mutation ([AuthRepository.firebaseAuth]); the native Firebase configuration
/// (`firebase_options.dart`, platform config) is added later, so for now the
/// buttons surface a "coming soon" message. Wire them to a real
/// `firebase_auth` + `google_sign_in` / `sign_in_with_apple` flow once the
/// config lands, then call `firebaseAuth(idToken)`.
class SocialLogin extends StatelessWidget {
  const SocialLogin({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.auth_socialComingSoon.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        OutlinedButton.icon(
          onPressed: () => _comingSoon(context),
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: Text(LocaleKeys.auth_continueWithGoogle.tr()),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _comingSoon(context),
          icon: const Icon(Icons.apple, size: 24),
          label: Text(LocaleKeys.auth_continueWithApple.tr()),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
