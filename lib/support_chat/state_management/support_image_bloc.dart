import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../data/support_chat_repository.dart';
import '../models/support_chat.dart';
import 'support_image_events.dart';
import 'support_image_state.dart';

/// Where a fresh signed link for an attachment comes from. The support chat and
/// the group wall sign through different queries, and this is the whole of the
/// difference — everything else about showing a picture is shared.
typedef AttachmentUrlResolver = Future<String> Function(String attachmentId);

/// One inline picture in a message bubble — or in a group post, which carries
/// the very same attachments.
///
/// Attachment links are signed for fifteen minutes only, and a chat that stays
/// open outlives that easily — the message list is re-read on every server
/// event, but a quiet conversation is never re-read at all. So the first time a
/// picture refuses to load, this asks the backend to sign a fresh link and
/// tries once more; only a second failure is taken at face value, which keeps a
/// genuinely broken attachment from re-signing forever.
@injectable
class SupportImageBloc extends Bloc<SupportImageEvent, SupportImageState> {
  SupportImageBloc(
    this._chat,
    @factoryParam this.attachment,
    @factoryParam this.resolveUrl,
  ) : super(SupportImageState(url: attachment.url ?? '')) {
    on<SupportImageLoadFailed>(_onLoadFailed);
  }

  final SupportChatRepository _chat;

  /// The attachment being shown. Its own `url` is only the starting point.
  final SupportAttachment attachment;

  /// How to re-sign it; `null` means the support chat's own query, which is
  /// where this started and still where most attachments live.
  final AttachmentUrlResolver? resolveUrl;

  Future<void> _onLoadFailed(
    SupportImageLoadFailed event,
    Emitter<SupportImageState> emit,
  ) async {
    if (state.failed || state.refreshed) {
      emit(state.copyWith(refreshed: true, failed: true));
      return;
    }
    emit(state.copyWith(refreshed: true));
    try {
      final url = await (resolveUrl ?? _chat.attachmentUrl)(attachment.id);
      if (emit.isDone) return;
      emit(
        url.isEmpty ? state.copyWith(failed: true) : state.copyWith(url: url),
      );
    } catch (_) {
      // Nothing the reader can act on: the bubble shows the placeholder, and
      // the next re-read of the thread brings a freshly signed link anyway.
      if (!emit.isDone) emit(state.copyWith(failed: true));
    }
  }
}
