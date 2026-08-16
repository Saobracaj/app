import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di.dart';
import '../../test/quest/preview/question_preview_sheet.dart';
import '../models/support_chat.dart';
import '../state_management/support_image_bloc.dart';
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

/// Hero tag of an inline picture. Shared by the thumbnail in the bubble and by
/// the full-screen viewer, so tapping one flies the photo into the other
/// instead of cutting to it.
String supportImageHeroTag(SupportAttachment attachment) =>
    'support-image-${attachment.id}';

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
    if (attachment.kind == SupportAttachmentKind.question) {
      return _QuestionChip(
        questionId: attachment.questionId,
        onSurface: onSurface,
      );
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
        ? _ImageAttachment(attachment: attachment)
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

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment});

  final SupportAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Keyed by attachment, so a re-read of the thread (which hands out freshly
      // signed links) starts the tile over instead of reusing a dead one.
      key: ValueKey(attachment.id),
      create: (_) {
        final bloc = getIt<SupportImageBloc>(param1: attachment);
        // No link at all is the same situation as an expired one: ask the
        // backend to sign one rather than showing a placeholder for good.
        final url = attachment.url;
        if (url == null || url.isEmpty) bloc.add(SupportImageLoadFailed());
        return bloc;
      },
      child: const _ImageTile(),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile();

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
                onTap: () => _openFullScreen(
                  context,
                  attachment.copyWith(url: state.url),
                ),
                child: Hero(
                  tag: supportImageHeroTag(attachment),
                  flightShuttleBuilder: supportImageFlight(state.url),
                  child: Image.network(
                    state.url,
                    // A re-signed link is a different image to Flutter's cache
                    // only if the widget is told so.
                    key: ValueKey(state.url),
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
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : _ImagePlaceholder(
                            fileName: attachment.fileName,
                            loading: true,
                          ),
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
        onTap: () => _download(context, attachment),
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

/// Open the signed URL with the platform handler: the browser downloads it (the
/// backend signs `Content-Disposition: attachment` with the original file name),
/// and on mobile the OS decides what opens it.
Future<void> _download(
  BuildContext context,
  SupportAttachment attachment,
) async {
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

/// What actually flies between the bubble and the full screen.
///
/// The default shuttle hands the flight to the widget it lands on, so a picture
/// shown cropped in the bubble (`cover`) would snap to its letterboxed shape in
/// the very first frame of the flight. Drawing the same cropped picture for the
/// whole way instead — into a rectangle that ends on the photo's own
/// proportions — lets the crop unwind continuously, and the rounded corners
/// straighten out along with it.
HeroFlightShuttleBuilder supportImageFlight(String url) {
  return (context, animation, direction, fromContext, toContext) {
    return AnimatedBuilder(
      animation: animation,
      // The picture is built once: only its clip depends on the animation.
      child: Image.network(url, fit: BoxFit.cover, gaplessPlayback: true),
      builder: (context, child) => ClipRRect(
        borderRadius: BorderRadius.circular(
          kSupportImageRadius * (1 - animation.value).clamp(0.0, 1.0),
        ),
        child: child,
      ),
    );
  };
}

/// Open the picture full screen.
///
/// The photo's proportions are looked up first, because the hero has to land on
/// exactly the rectangle the photo will occupy — otherwise the flight ends on a
/// letterboxed box and the picture jumps on the last frame. The same bytes are
/// already decoded for the thumbnail, so the answer comes back from the image
/// cache within a frame; when it does not, the viewer letterboxes as before
/// rather than making the tap wait.
Future<void> _openFullScreen(
  BuildContext context,
  SupportAttachment attachment,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final url = attachment.url ?? '';
  final aspectRatio = url.isEmpty ? null : await _imageAspectRatio(url);
  if (!navigator.mounted) return;
  navigator.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          _FullScreenImage(attachment: attachment, aspectRatio: aspectRatio),
    ),
  );
}

/// Width-to-height of the decoded picture, or `null` if it is not there to be
/// had quickly — a link that has expired since the thumbnail loaded, or a
/// picture still on its way.
Future<double?> _imageAspectRatio(String url) {
  final completer = Completer<double?>();
  final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void finish(double? ratio) {
    if (!completer.isCompleted) completer.complete(ratio);
    stream.removeListener(listener);
  }

  listener = ImageStreamListener((info, _) {
    final ratio = info.image.width / info.image.height;
    info.dispose();
    finish(ratio.isFinite && ratio > 0 ? ratio : null);
  }, onError: (_, _) => finish(null));
  stream.addListener(listener);
  return completer.future.timeout(
    const Duration(milliseconds: 300),
    onTimeout: () {
      stream.removeListener(listener);
      return null;
    },
  );
}

/// Full-screen image viewer: pinch/zoom over a black backdrop, with the same
/// download action as a file attachment.
class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.attachment, this.aspectRatio});

  final SupportAttachment attachment;

  /// Proportions of the photo, when they were known at open time — the hero
  /// lands on a box of exactly this shape, so `cover` and `contain` coincide.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final url = attachment.url ?? '';
    final image = Image.network(
      url,
      fit: aspectRatio == null ? BoxFit.contain : BoxFit.cover,
      errorBuilder: (context, _, _) => Center(
        child: Text(
          'support.imageUnavailable'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
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
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Hero(
            tag: supportImageHeroTag(attachment),
            flightShuttleBuilder: supportImageFlight(url),
            // Without the proportions the picture letterboxes across the whole
            // body; a photo bigger than the screen used to overflow it.
            child: aspectRatio == null
                ? SizedBox.expand(child: image)
                : AspectRatio(aspectRatio: aspectRatio!, child: image),
          ),
        ),
      ),
    );
  }
}
