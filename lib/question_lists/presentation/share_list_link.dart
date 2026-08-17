import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../generated/locale_keys.g.dart';
import '../models/question_list_share.dart';

/// Hand a list's share link over: the system share sheet on mobile, the
/// clipboard on the web (where `navigator.share` is missing on most desktop
/// browsers and share_plus's fallback opens a `mailto:` — not what a person
/// pasting a link into a messenger wants). Falls back to the clipboard when
/// the sheet is unavailable.
Future<void> presentQuestionListShare(
  BuildContext context,
  QuestionListShare share,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!kIsWeb) {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: share.url),
      );
      if (result.status != ShareResultStatus.unavailable) return;
    } catch (_) {
      // Fall through to the clipboard.
    }
  }
  await Clipboard.setData(ClipboardData(text: share.url));
  messenger.showSnackBar(
    SnackBar(content: Text(LocaleKeys.questionLists_share_linkCopied.tr())),
  );
}
