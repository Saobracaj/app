import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';
import '../data/push_message.dart';

/// The in-app rendering of a push notification that arrived while the app was
/// on screen: the title in bold, the body underneath, and a «go» action when
/// the notification leads somewhere.
///
/// Built as a plain [SnackBar] so it can be shown from the app root through a
/// `ScaffoldMessenger` key — above whatever screen is open — and asserted on
/// in widget tests.
SnackBar buildPushMessageSnackBar(
  PushMessage push, {
  required VoidCallback? onOpen,
}) {
  final title = push.title;
  final body = push.body;
  return SnackBar(
    key: const ValueKey('pushMessageSnackBar'),
    // Long enough to read two lines and reach for the button; a tap anywhere
    // else dismisses it as usual.
    duration: const Duration(seconds: 8),
    behavior: SnackBarBehavior.floating,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (body != null)
          Text(body, maxLines: 4, overflow: TextOverflow.ellipsis),
      ],
    ),
    action: onOpen == null
        ? null
        : SnackBarAction(label: LocaleKeys.pushMessage_open.tr(), onPressed: onOpen),
  );
}
