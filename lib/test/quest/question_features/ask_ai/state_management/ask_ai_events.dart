/// Events of [AskAiBloc].
sealed class AskAiEvent {}

/// Load (or retry loading) the question's pre-generated explanation.
class AskAiRequested extends AskAiEvent {}
