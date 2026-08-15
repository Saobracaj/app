import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:saobracaj/core/deep_links.dart';
import 'package:saobracaj/core/navigation.dart';
import 'package:saobracaj/generated/locale_keys.g.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/test/animations/animations_map.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';
import 'package:saobracaj/test/quest/preview/question_preview_sheet.dart';
import 'package:saobracaj/util/nav_to_url.dart';
import 'package:saobracaj/zakon/presentation/zakon_panel.dart';

/// Markdown renderer for konspekt content. On top of the shared markdown
/// styling it understands konspekt link schemes:
///
/// - `question?id=7921` — opens the question in a preview sheet over the text;
/// - `konspekt?category=25&section=slug` — same-konspekt links scroll in place
///   (via [onSectionLink]), links to another category push a new page;
/// - `zakon?...`, `dict/...`, `https://<deep-link-host>/...` — same handling
///   as [QuestMarkdown];
/// - `![alt](illustration:slug)` — renders a placeholder card (the artwork
///   will be produced later).
class KonspektMarkdown extends StatelessWidget {
  const KonspektMarkdown({
    super.key,
    required this.text,
    this.categoryId,
    this.onSectionLink,
    this.padding,
  });

  final String text;

  /// The category of the konspekt this markdown belongs to; used to detect
  /// same-document section links.
  final String? categoryId;

  /// Called for links into a section of the same konspekt.
  final void Function(String sectionId)? onSectionLink;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      shrinkWrap: true,
      selectable: false,
      physics: const NeverScrollableScrollPhysics(),
      data: text,
      onTapLink: (_, href, _) => _onTapLink(context, href),
      padding: padding ?? EdgeInsets.zero,
      styleSheet: MarkdownStyleSheet(
        a: TextStyle(color: Theme.of(context).colorScheme.primary),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withAlpha(40),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
      sizedImageBuilder: (config) {
        final uri = config.uri.toString();
        if (uri.startsWith('illustration:')) {
          return _IllustrationPlaceholder(alt: config.alt ?? config.title);
        }
        if (uri.startsWith('anim/')) {
          return getAnimation(uri.split('anim/')[1]);
        }
        if (uri.startsWith('http')) {
          return Image.network(uri);
        }
        return Image.asset('assets/md_img/$uri');
      },
    );
  }

  void _onTapLink(BuildContext context, String? href) {
    if (href == null) return;
    var link = href;
    if (link.startsWith('https://$kDeepLinkHost/')) {
      link = link.substring('https://$kDeepLinkHost'.length);
    }
    if (link.startsWith('dict/')) {
      showMarkdown(context, Uri.decodeFull(link.split('/')[1]));
      return;
    }
    final uri = Uri.parse(link);
    switch (uri.path.replaceFirst('/', '')) {
      case 'question':
        final id = int.tryParse(uri.queryParameters['id'] ?? '');
        // A question referenced from a text opens over that text, not instead
        // of it: reading continues right where it stopped.
        if (id != null) showQuestionPreview(context, id);
      case 'konspekt':
        final category = uri.queryParameters['category'];
        final section = uri.queryParameters['section'];
        if (section != null && category == categoryId && onSectionLink != null) {
          onSectionLink!(section);
        } else if (category != null) {
          pushScreen(
            context,
            path: 'konspekt',
            queryParameters: {'category': category, 'section': ?section},
            screen: () => KonspektPage(categoryId: category, section: section),
          );
        }
      case 'zakon':
        // Relative: the law opens on top of whatever screen this text is on
        // (a konspekt, a question, the preview sheet), so "back" returns here.
        openZakon(context, 'zakon', queryParameters: uri.queryParameters);
      default:
        navigateToUri(context, Uri.parse(href));
    }
  }
}

/// A stand-in card for a not-yet-produced illustration or animation.
class _IllustrationPlaceholder extends StatelessWidget {
  const _IllustrationPlaceholder({this.alt});

  final String? alt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withAlpha(60)),
      ),
      child: Column(
        children: [
          Icon(Icons.image_outlined, size: 48, color: colorScheme.secondary),
          if (alt != null && alt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alt!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            LocaleKeys.konspekt_illustrationPlaceholder.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
