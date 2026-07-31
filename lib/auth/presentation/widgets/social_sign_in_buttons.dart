import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../generated/locale_keys.g.dart';

/// Brand-compliant "Continue with Google / Apple" buttons.
///
/// These replace the `firebase_ui_auth` `OAuthProviderButton`, whose bundled
/// styles still follow Google's *pre-2022* branding (a solid blue button with a
/// white icon tile) and Apple's fixed style. The buttons here follow the current
/// guidelines and adapt to the app's light/dark theme:
///
/// * **Google** — <https://developers.google.com/identity/branding-guidelines>:
///   light = white surface, `#747775` stroke, `#1F1F1F` label; dark = `#131314`
///   surface, `#8E918F` stroke, `#E3E3E3` label. The multi-colour "G" mark is
///   never recoloured.
/// * **Apple** — Human Interface Guidelines "Sign in with Apple": a black button
///   on light backgrounds and a white button on dark backgrounds; the Apple mark
///   and label share the button's foreground colour.
///
/// Both use a fully rounded ("pill") shape per the request, a fixed height, and
/// an in-place fixed-size spinner while [busy] (so the indicator can never be
/// stretched into an oval by a parent `Column(crossAxisAlignment: stretch)`).

const double _buttonHeight = 48;
const double _logoSize = 20;
const double _spinnerSize = 22;

/// "Continue with Google" button.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.busy,
  });

  /// Tapped to start the Google OAuth flow. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether a sign-in is in progress; shows a spinner and blocks taps.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SocialPillButton(
      label: LocaleKeys.auth_continueWithGoogle.tr(),
      backgroundColor:
          isDark ? const Color(0xFF131314) : const Color(0xFFFFFFFF),
      foregroundColor:
          isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
      borderColor: isDark ? const Color(0xFF8E918F) : const Color(0xFF747775),
      logo: const _GoogleLogo(),
      onPressed: onPressed,
      busy: busy,
    );
  }
}

/// "Continue with Apple" button.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.onPressed,
    required this.busy,
  });

  /// Tapped to start the Apple OAuth flow. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether a sign-in is in progress; shows a spinner and blocks taps.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return _SocialPillButton(
      label: LocaleKeys.auth_continueWithApple.tr(),
      backgroundColor:
          isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      foregroundColor: foreground,
      // The Apple mark is monochrome and takes the button's foreground colour.
      logo: Icon(Icons.apple, size: 22, color: foreground),
      onPressed: onPressed,
      busy: busy,
    );
  }
}

/// Shared pill-shaped shell: full-width, fixed height, `[logo] [label]` centred
/// as a group, or a fixed-size spinner while [busy].
class _SocialPillButton extends StatelessWidget {
  const _SocialPillButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.logo,
    required this.onPressed,
    required this.busy,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget logo;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final border = borderColor;
    return SizedBox(
      height: _buttonHeight,
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(
          side: border != null ? BorderSide(color: border) : BorderSide.none,
        ),
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: _spinnerSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The official multi-colour Google "G" mark (never recoloured per brand rules).
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_googleGSvg, width: _logoSize, height: _logoSize);
}

const String _googleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';
