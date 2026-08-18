import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../test/quest/preview/question_preview_sheet.dart';
import '../data/chat_image_cache.dart';
import '../models/support_chat.dart';
import 'chat_photo_viewer.dart';
import '../state_management/support_image_bloc.dart'
    show AttachmentUrlResolver, SupportImageBloc;
import '../state_management/support_image_events.dart';
import '../state_management/support_image_state.dart';

/// The box every inline picture occupies, whatever it turns out to contain.
///
/// A fixed size is the whole point: the bubble is laid out before a single byte
/// of the image has arrived, so a conversation no longer jumps around under the
/// reader's finger as pictures decode one after another.
const double kSupportImageWidth = 240;
const double kSupportImageHeight = 180;

/// Rounding of that box — also where the flight to full screen starts from.
const double kSupportImageRadius = 12;

/// How one attachment is rendered — inside a message bubble, and inside a group
/// post, which carries attachments of exactly the same shape.
///
/// * an **image** is previewed inline and opens full-screen on tap, with a
///   download action in the viewer;
/// * a **file** is a row that downloads on tap;
/// * a **question** is a chip «вопрос 1234» that opens the existing preview
///   sheet — the same one the konspekt's question links use;
/// * a **question list** is one chip too: the list's name, and a sheet with the
///   questions behind it.
class SupportAttachmentView extends StatelessWidget {
  const SupportAttachmentView({
    super.key,
    required this.attachment,
    required this.onSurface,
    this.resolveUrl,
    this.gallery = const <SupportAttachment>[],
  });

  final SupportAttachment attachment;

  /// Все фотографии сообщения, в порядке показа: полноэкранный просмотр листает
  /// их свайпами, а не показывает одну-единственную. Пустой список — «только
  /// эта», для мест, где соседних фотографий нет.
  final List<SupportAttachment> gallery;

  /// Colour to draw on, so the widget reads on both bubble backgrounds.
  final Color onSurface;

  /// How to re-sign an expired link. `null` for the support chat's own
  /// attachments; the group wall passes its own query.
  final AttachmentUrlResolver? resolveUrl;

  @override
  Widget build(BuildContext context) {
    if (attachment.kind == SupportAttachmentKind.question) {
      return _QuestionChip(
        questionId: attachment.questionId,
        onSurface: onSurface,
      );
    }
    if (attachment.kind == SupportAttachmentKind.questionList) {
      return _QuestionListChip(attachment: attachment, onSurface: onSurface);
    }
    if (attachment.deleted) {
      return _DeletedAttachment(
        isImage: attachment.isImage,
        onSurface: onSurface,
      );
    }
    // Deliberately `isImage` and not `kind`: a picture uploaded before the app
    // reported MIME types is stored as a plain file and would otherwise stay
    // hidden behind a download row forever.
    return attachment.isImage
        ? _ImageAttachment(
            attachment: attachment,
            resolveUrl: resolveUrl,
            gallery: gallery.isEmpty ? [attachment] : gallery,
          )
        : _FileAttachment(attachment: attachment, onSurface: onSurface);
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

/// A shared question list: one chip with the list's name, and a sheet with the
/// questions it held when it was shared. Deliberately the same gesture as the
/// single-question chip — the reader taps a name and sees questions.
class _QuestionListChip extends StatelessWidget {
  const _QuestionListChip({required this.attachment, required this.onSurface});

  final SupportAttachment attachment;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final ids = attachment.questionIds;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ActionChip(
        avatar: Icon(Icons.playlist_add_check, size: 18, color: onSurface),
        label: Text(
          '${attachment.fileName} · ${ids.length}',
          overflow: TextOverflow.ellipsis,
        ),
        labelStyle: TextStyle(color: onSurface),
        onPressed: ids.isEmpty
            ? null
            : () => showSharedQuestionList(context, attachment),
      ),
    );
  }
}

/// The questions of a shared list, each opening the usual preview sheet.
Future<void> showSharedQuestionList(
  BuildContext context,
  SupportAttachment attachment,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              attachment.fileName,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final id in attachment.questionIds)
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text('support.questionChip'.tr(args: ['$id'])),
                    onTap: () => showQuestionPreview(sheetContext, id),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.attachment,
    required this.gallery,
    this.resolveUrl,
  });

  final SupportAttachment attachment;
  final List<SupportAttachment> gallery;
  final AttachmentUrlResolver? resolveUrl;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Keyed by attachment, so a re-read of the thread (which hands out freshly
      // signed links) starts the tile over instead of reusing a dead one.
      key: ValueKey(attachment.id),
      create: (_) {
        final bloc = getIt<SupportImageBloc>(
          param1: attachment,
          param2: resolveUrl,
        );
        // No link at all is the same situation as an expired one: ask the
        // backend to sign one rather than showing a placeholder for good.
        final url = attachment.url;
        if (url == null || url.isEmpty) bloc.add(SupportImageLoadFailed());
        return bloc;
      },
      child: _ImageTile(gallery: gallery, resolveUrl: resolveUrl),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.gallery, this.resolveUrl});

  final List<SupportAttachment> gallery;
  final AttachmentUrlResolver? resolveUrl;

  @override
  Widget build(BuildContext context) {
    final attachment = context.read<SupportImageBloc>().attachment;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSupportImageRadius),
        child: SizedBox(
          width: kSupportImageWidth,
          height: kSupportImageHeight,
          child: BlocBuilder<SupportImageBloc, SupportImageState>(
            builder: (context, state) {
              if (!state.hasUrl) {
                return _ImagePlaceholder(
                  fileName: attachment.fileName,
                  loading: !state.failed,
                );
              }
              return InkWell(
                onTap: () => showChatPhotos(
                  context,
                  photos: gallery,
                  initialIndex: gallery.indexWhere((a) => a.id == attachment.id)
                      .clamp(0, gallery.length - 1),
                  resolveUrl: resolveUrl,
                ),
                child: Hero(
                  tag: supportImageHeroTag(attachment),
                  child: Image(
                    // Ключ — id вложения, а не подписанная ссылка: та меняется
                    // при каждом перечитывании переписки, и без кэша по id одна
                    // и та же фотография качалась заново при каждом
                    // пролистывании истории.
                    image: CachedChatImage(
                      attachmentId: attachment.id,
                      url: state.url,
                    ),
                    width: kSupportImageWidth,
                    height: kSupportImageHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, _) {
                      // Reporting during a build is not allowed; the Bloc
                      // ignores everything after the one retry, so repeats are
                      // harmless.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          context.read<SupportImageBloc>().add(
                            SupportImageLoadFailed(),
                          );
                        }
                      });
                      return _ImagePlaceholder(
                        fileName: attachment.fileName,
                        loading: !state.refreshed,
                      );
                    },
                    frameBuilder: (context, child, frame, wasSync) =>
                        frame == null && !wasSync
                        ? _ImagePlaceholder(
                            fileName: attachment.fileName,
                            loading: true,
                          )
                        : child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// What fills the picture's box before it arrives, and instead of it when it
/// never does — the same size either way, so nothing moves.
/// What is left of a photo or file whose uploader deleted their account: a
/// muted note in the attachment's place, so the conversation keeps its shape.
class _DeletedAttachment extends StatelessWidget {
  const _DeletedAttachment({required this.isImage, required this.onSurface});

  final bool isImage;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: onSurface.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImage ? Icons.hide_image_outlined : Icons.file_present_outlined,
            size: 18,
            color: onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              (isImage ? 'support.imageDeleted' : 'support.fileDeleted').tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.fileName, this.loading = false});

  final String fileName;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kSupportImageWidth,
      height: kSupportImageHeight,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fileName.isEmpty
                        ? 'support.imageUnavailable'.tr()
                        : fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
        onTap: () => downloadAttachment(context, attachment),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 20,
                color: onSurface,
              ),
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
