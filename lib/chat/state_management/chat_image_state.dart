import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_image_state.freezed.dart';

/// State of one inline picture in a message bubble.
@freezed
abstract class ChatImageState with _$ChatImageState {
  const factory ChatImageState({
    /// The link the picture is currently being loaded from. Empty means there is
    /// nothing to show — either the attachment came without one, or re-signing
    /// it failed.
    @Default('') String url,

    /// A fresh link has already been asked for, so a second failure is the
    /// picture's own and not an expired signature.
    @Default(false) bool refreshed,

    /// Loading is over and unsuccessful: show the placeholder instead.
    @Default(false) bool failed,
  }) = _ChatImageState;

  const ChatImageState._();

  bool get hasUrl => url.isNotEmpty && !failed;
}
