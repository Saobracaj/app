/// Полноэкранный просмотр фотографий из чата.
///
/// Три жеста и одна клавиатура:
///
/// * **вверх/вниз** — смахнуть фотографию и закрыть просмотр, как в Telegram:
///   картинка едет за пальцем, фон выцветает, и по отпусканию либо возвращается
///   на место, либо улетает. На вебе выключено — там вертикальное перетаскивание
///   мышью ничего не означает, и требование это прямо оговаривает;
/// * **влево/вправо** — соседняя фотография того же сообщения;
/// * **щипок** — зум; пока картинка увеличена, оба предыдущих жеста уступают
///   место панорамированию, иначе двигать увеличенный снимок было бы нечем;
/// * **←/→** на клавиатуре — то же листание, для веба и планшета с клавиатурой.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di.dart';
import '../data/chat_image_cache.dart';
import '../models/support_chat.dart';
import '../state_management/support_image_bloc.dart'
    show AttachmentUrlResolver, SupportImageBloc;
import '../state_management/support_image_events.dart';
import '../state_management/support_image_state.dart';


/// Насколько далеко нужно утащить фотографию, чтобы отпускание её закрыло.
const double _dismissDistance = 120;

/// Либо расстояние, либо скорость: короткий резкий флик закрывает так же, как
/// медленное долгое перетаскивание.
const double _dismissVelocity = 700;

/// Открыть [photos] на элементе [initialIndex].
///
/// [resolveUrl] — как получить свежую подписанную ссылку, если та, что уже
/// есть, протухла; повторяет договорённость `SupportImageBloc`.
Future<void> showChatPhotos(
  BuildContext context, {
  required List<SupportAttachment> photos,
  required int initialIndex,
  AttachmentUrlResolver? resolveUrl,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      // Фон непрозрачный только к концу перехода: пока летит hero, под ним
      // должен просвечивать чат — иначе фотография вылетает из чёрного поля.
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => ChatPhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        resolveUrl: resolveUrl,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Галерея фотографий одного сообщения.
class ChatPhotoViewer extends StatefulWidget {
  const ChatPhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    this.resolveUrl,
  });

  final List<SupportAttachment> photos;
  final int initialIndex;
  final AttachmentUrlResolver? resolveUrl;

  @override
  State<ChatPhotoViewer> createState() => _ChatPhotoViewerState();
}

class _ChatPhotoViewerState extends State<ChatPhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// Насколько фотография утащена от центра, пока палец на экране.
  Offset _drag = Offset.zero;

  /// Текущая картинка увеличена: листание и смахивание уступают место
  /// панорамированию.
  bool _zoomed = false;

  /// Смахивание есть везде, кроме веба.
  bool get _dismissible => !kIsWeb;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  SupportAttachment get _current => widget.photos[_index];

  /// Доля пути до закрытия, 0..1 — по ней гаснет фон и уменьшается картинка.
  double get _progress =>
      (_drag.dy.abs() / (_dismissDistance * 2)).clamp(0.0, 1.0);

  void _goTo(int index) {
    if (index < 0 || index >= widget.photos.length) return;
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _goTo(_index - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _goTo(_index + 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dismissible || _zoomed) return;
    setState(() => _drag += details.delta);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dismissible || _zoomed) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final far = _drag.dy.abs() > _dismissDistance;
    final fast = velocity.abs() > _dismissVelocity;
    if (far || fast) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.photos.length > 1;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 1 - _progress),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            many
                ? '${_index + 1} / ${widget.photos.length}'
                : _current.fileName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: 'support.download'.tr(),
              icon: const Icon(Icons.download_outlined),
              onPressed: () => downloadAttachment(context, _current),
            ),
          ],
        ),
        body: PageView.builder(
          controller: _pages,
          // Пока картинка увеличена, горизонтальные жесты принадлежат ей.
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: widget.photos.length,
          onPageChanged: (index) => setState(() {
            _index = index;
            _zoomed = false;
            _drag = Offset.zero;
          }),
          itemBuilder: (context, index) {
            final attachment = widget.photos[index];
            final page = _PhotoPage(
              attachment: attachment,
              resolveUrl: widget.resolveUrl,
              onScaleChanged: (zoomed) {
                if (zoomed != _zoomed && index == _index) {
                  setState(() => _zoomed = zoomed);
                }
              },
            );
            // Hero есть только у той фотографии, из которой пришли: остальные
            // в чате не видны, и лететь им не от чего.
            final hero = index == widget.initialIndex
                ? Hero(
                    tag: supportImageHeroTag(attachment),
                    child: page,
                  )
                : page;
            if (index != _index) return hero;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Transform.translate(
                offset: _drag,
                child: Transform.scale(
                  // Чуть уменьшить утаскиваемую картинку — тот же приём, что в
                  // мессенджерах: она визуально «отрывается» от экрана.
                  scale: 1 - _progress * 0.2,
                  child: hero,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Одна фотография: зум и панорамирование. Пересогласование протухшей
/// подписанной ссылки — дело [SupportImageBloc], того же, что и у плитки в
/// пузыре: правило «одна ссылка, одна повторная подпись» не должно быть
/// записано в приложении дважды.
class _PhotoPage extends StatelessWidget {
  const _PhotoPage({
    required this.attachment,
    required this.onScaleChanged,
    this.resolveUrl,
  });

  final SupportAttachment attachment;
  final ValueChanged<bool> onScaleChanged;
  final AttachmentUrlResolver? resolveUrl;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = getIt<SupportImageBloc>(
          param1: attachment,
          param2: resolveUrl,
        );
        final url = attachment.url;
        if (url == null || url.isEmpty) bloc.add(SupportImageLoadFailed());
        return bloc;
      },
      child: _PhotoSurface(
        attachment: attachment,
        onScaleChanged: onScaleChanged,
      ),
    );
  }
}

/// Stateful ровно ради контроллера трансформации — состояние чисто визуальное.
class _PhotoSurface extends StatefulWidget {
  const _PhotoSurface({required this.attachment, required this.onScaleChanged});

  final SupportAttachment attachment;
  final ValueChanged<bool> onScaleChanged;

  @override
  State<_PhotoSurface> createState() => _PhotoSurfaceState();
}

class _PhotoSurfaceState extends State<_PhotoSurface> {
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  void _onTransform() =>
      widget.onScaleChanged(_transform.value.getMaxScaleOnAxis() > 1.01);

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportImageBloc, SupportImageState>(
      builder: (context, state) {
        if (!state.hasUrl) {
          return Center(
            child: state.failed
                ? Text(
                    'support.imageUnavailable'.tr(),
                    style: const TextStyle(color: Colors.white),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          );
        }
        return InteractiveViewer(
          transformationController: _transform,
          maxScale: 5,
          child: Center(
            child: Image(
              image: CachedChatImage(
                attachmentId: widget.attachment.id,
                url: state.url,
              ),
              fit: BoxFit.contain,
              errorBuilder: (context, _, _) {
                // Сообщать об ошибке во время построения нельзя; блок после
                // единственной повторной подписи всё игнорирует.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.read<SupportImageBloc>().add(
                      SupportImageLoadFailed(),
                    );
                  }
                });
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              frameBuilder: (context, child, frame, wasSync) =>
                  frame == null && !wasSync
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : child,
            ),
          ),
        );
      },
    );
  }
}

/// Тег hero одной фотографии — общий у плитки в пузыре и у страницы просмотра.
String supportImageHeroTag(SupportAttachment attachment) =>
    'support-image-${attachment.id}';

/// Открыть подписанную ссылку системным обработчиком: браузер скачает файл
/// (бэкенд подписывает `Content-Disposition: attachment` с исходным именем), а
/// на телефоне ОС сама решит, чем его открыть.
Future<void> downloadAttachment(
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
