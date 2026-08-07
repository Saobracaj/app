import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/deep_links.dart';

/// A link found inside a message body: where it sits in the text and where it
/// points.
class TextLink {
  const TextLink({required this.start, required this.end, required this.uri});

  /// Half-open range of the link inside the original text.
  final int start;
  final int end;

  /// The address to open, with a scheme filled in for a bare `www.` link.
  final Uri uri;
}

/// Anything that starts a link: an explicit scheme, or the `www.` people type
/// instead of one.
final _linkPattern = RegExp(
  r'(?:https?://|www\.)[^\s<>"' r"']+",
  caseSensitive: false,
);

/// Trailing characters that end a sentence far more often than they belong to
/// the address — `…смотри https://example.com/a.` should not link the dot.
const _trailingPunctuation = '.,;:!?»"\'';

/// Every link in [text], in order, with sentence punctuation and unbalanced
/// closing brackets left out of the address.
List<TextLink> findLinks(String text) {
  final links = <TextLink>[];
  for (final match in _linkPattern.allMatches(text)) {
    var raw = match.group(0)!;
    var end = match.end;
    while (raw.isNotEmpty) {
      final last = raw[raw.length - 1];
      final unbalanced =
          (last == ')' && !_balanced(raw, '(', ')')) ||
          (last == ']' && !_balanced(raw, '[', ']'));
      if (!_trailingPunctuation.contains(last) && !unbalanced) break;
      raw = raw.substring(0, raw.length - 1);
      end--;
    }
    if (raw.isEmpty) continue;
    final uri = Uri.tryParse(
      raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw,
    );
    if (uri == null || uri.host.isEmpty) continue;
    links.add(TextLink(start: match.start, end: end, uri: uri));
  }
  return links;
}

bool _balanced(String s, String open, String close) {
  var depth = 0;
  for (final c in s.split('')) {
    if (c == open) depth++;
    if (c == close) depth--;
  }
  return depth >= 0;
}

/// Whether [uri] stays inside the product — the app's own public host, or a
/// subdomain of it.
bool isInternalLink(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == kDeepLinkHost || host.endsWith('.$kDeepLinkHost');
}

/// Open [uri], asking first when it leaves the product.
///
/// A support chat is a place where strangers paste addresses at each other, so
/// an outside link never opens on a single tap: the dialog shows where it
/// actually goes before the browser does.
Future<void> openMessageLink(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!isInternalLink(uri)) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('support.externalLinkTitle'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('support.externalLinkBody'.tr()),
            const SizedBox(height: 12),
            SelectableText(
              uri.toString(),
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('support.externalLinkCancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('support.externalLinkOpen'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    messenger?.showSnackBar(
      SnackBar(content: Text('support.linkFailed'.tr())),
    );
  }
}

/// Message text with its links highlighted and tappable.
///
/// Stateful for one reason only, the same one an `AnimationController` is:
/// [TapGestureRecognizer]s have to be disposed with the widget. Everything the
/// widget decides comes from its arguments.
class LinkedText extends StatefulWidget {
  const LinkedText({
    super.key,
    required this.text,
    this.style,
    required this.linkColor,
  });

  final String text;
  final TextStyle? style;

  /// Colour of a link, so it reads on whichever bubble it lands in.
  final Color linkColor;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final links = findLinks(widget.text);
    if (links.isEmpty) return Text(widget.text, style: widget.style);

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final linkStyle = (widget.style ?? const TextStyle()).copyWith(
      color: widget.linkColor,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor,
    );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final link in links) {
      if (link.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, link.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (mounted) openMessageLink(context, link.uri);
        };
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: widget.text.substring(link.start, link.end),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = link.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
