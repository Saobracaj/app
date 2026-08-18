/// What can happen to one inline picture.
sealed class ChatImageEvent {}

/// The picture would not load from the link currently in state.
class SupportImageLoadFailed extends ChatImageEvent {}
