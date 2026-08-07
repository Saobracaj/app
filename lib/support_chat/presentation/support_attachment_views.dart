import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../test/quest/preview/question_preview_sheet.dart';
import '../models/support_chat.dart';

/// How one attachment is rendered inside a message bubble.
///
/// * an **image** is previewed inline and opens full-screen on tap, with a
///   download action in the viewer;
/// * a **file** is a row that downloads on tap;
/// * a **question** is a chip «вопрос 1234» that opens the existing preview
///   sheet — the same one the konspekt's question links use.
class SupportAttachmentView extends StatelessWidget {
  const SupportAttachmentView({
    super.key,
    required this.attachment,
    required this.onSurface,
  });

  final SupportAttachment attachment;

  /// Colour to draw on, so the widget reads on both bubble backgrounds.
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return switch (attachment.kind) {
      SupportAttachmentKind.question => _QuestionChip(
        questionId: attachment.questionId,
        onSurface: onSurface,
      ),
      SupportAttachmentKind.image => _ImageAttachment(attachment: attachment),
      SupportAttachmentKind.file => _FileAttachment(
        attachment: attachment,
        onSurface: onSurface,
      ),
    };
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.questionId, required this.onSurface});

  final int? questionId;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final id = questionId;
    if (id == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ActionChip(
        avatar: Icon(Icons.help_outline, size: 18, color: onSurface),
        label: Text('support.questionChip'.tr(args: ['$id'])),
        labelStyle: TextStyle(color: onSurface),
        onPressed: () => showQuestionPreview(context, id),
      ),
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment});

  final SupportAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final url = attachment.url;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openFullScreen(context, attachment),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => _BrokenImage(
                fileName: attachment.fileName,
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 120,
                      width: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage({required this.fileName});
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: 160,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          fileName.isEmpty ? 'support.imageUnavailable'.tr() : fileName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment, required this.onSurface});

  final SupportAttachment attachment;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final size = attachment.readableSize;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: () => _download(context, attachment),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 20, color: onSurface),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onSurface,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    if (size.isNotEmpty)
                      Text(
                        size,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.download_outlined, size: 20, color: onSurface),
            ],
          ),
        ),
      ),
    );
  }
}

/// Open the signed URL with the platform handler: the browser downloads it (the
/// backend signs `Content-Disposition: attachment` with the original file name),
/// and on mobile the OS decides what opens it.
Future<void> _download(BuildContext context, SupportAttachment attachment) async {
  final url = attachment.url;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (url == null || url.isEmpty) {
    messenger?.showSnackBar(
      SnackBar(content: Text('support.attachmentUnavailable'.tr())),
    );
    return;
  }
  final launched = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    messenger?.showSnackBar(
      SnackBar(content: Text('support.downloadFailed'.tr())),
    );
  }
}

/// Full-screen image viewer: pinch/zoom over a black backdrop, with the same
/// download action as a file attachment.
void _openFullScreen(BuildContext context, SupportAttachment attachment) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenImage(attachment: attachment),
    ),
  );
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.attachment});

  final SupportAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          attachment.fileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'support.download'.tr(),
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _download(context, attachment),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            attachment.url ?? '',
            errorBuilder: (context, _, _) => Text(
              'support.imageUnavailable'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
