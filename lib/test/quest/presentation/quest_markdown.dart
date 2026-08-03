import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/core/deep_links.dart';
import 'package:saobracaj/dictionary/dictionary.dart';
import 'package:saobracaj/test/animations/animations_map.dart';
import 'package:saobracaj/util/nav_to_url.dart';

class QuestMarkdown extends StatelessWidget {
  const QuestMarkdown({
    super.key,
    required this.text,
    this.padding,
    this.useLargeText = true,
    this.pStyle,
  });

  final String text;
  final EdgeInsets? padding;
  final bool useLargeText;

  /// Overrides the paragraph style. Markdown ignores [DefaultTextStyle], so
  /// this is the only way a host (e.g. a highlighted answer card) can tint the
  /// body text. Takes precedence over [useLargeText].
  final TextStyle? pStyle;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      shrinkWrap: true,
      selectable: false,
      physics: NeverScrollableScrollPhysics(),
      data: text,
      onTapLink: (text, href, title) => openDictionary(context, href),
      padding: padding ?? EdgeInsets.zero,
      styleSheet: MarkdownStyleSheet(
        p:
            pStyle ??
            (useLargeText ? Theme.of(context).textTheme.bodyLarge : null),
        a: TextStyle(color: Theme.of(context).colorScheme.primary),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withAlpha(40),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
      sizedImageBuilder: (config) {
        final uri = config.uri.toString();

        final Widget imageWidget;
        if (uri.toString().startsWith('anim/')) {
          final animationName = uri.split('anim/')[1];
          imageWidget = getAnimation(animationName);
        } else if (uri.startsWith('http')) {
          imageWidget = Image.network(uri);
        } else {
          imageWidget = Image.asset('assets/md_img/$uri');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            if (config.title != null)
              Text(
                config.title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            SizedBox(height: 8),
            imageWidget,
            SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void openDictionary(BuildContext context, String? href) async {
    if (href == null) return;
    if (href.startsWith('dict/')) {
      final link = href.split('/')[1];

      showMarkdown(context, Uri.decodeFull(link));
    } else if (href.startsWith('/zakon')) {
      final link = href.split('/')[1];
      Routemaster.of(context).push(link);
    } else if (href.startsWith('zakon')) {
      Routemaster.of(context).push(href);
    } else if (href.startsWith('https://$kDeepLinkHost/')) {
      final link = href.split('https://$kDeepLinkHost/')[1];
      Routemaster.of(context).push(link);
    } else {
      navigateToUri(context, Uri.parse(href));
    }
  }
}

Future showMarkdown(BuildContext context, String link) async {
  final o = getDictByTitle(link);
  if (o == null) return;
  final String text = o['sr'];

  final paragraph = o['paragraph'];
  final chlan = o['chlan'];
  final chapter = o['chapter'];

  final uriPath = 'zakon?paragraph=$paragraph&chlan=$chlan&chapter=$chapter';

  final res = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        // Для того чтобы bottom sheet не обрезался под клавиатурой
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  ((o['title'] as String?)?.capitalize() ?? '').fixMd,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                onTap: () {
                  Routemaster.of(context).push(uriPath);
                },
                subtitle: Text(
                  'Закон о безбедности саобраћаја на путевима, члан $chlan',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              SizedBox(height: 16),
              QuestMarkdown(
                text: text.fixMd,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              if (o['ru'] != null) ...[
                SizedBox(height: 16),
                QuestMarkdown(
                  text: (o['ru'] as String).fixMd,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ],

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Back'),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
  return res;
}

extension _FixChlan on String {
  String get fixMd => replaceAll('<sup>', '').replaceAll('</sup>', '').trim();
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
