/// What can happen to one inline picture.
sealed class SupportImageEvent {}

/// The picture would not load from the link currently in state.
class SupportImageLoadFailed extends SupportImageEvent {}
