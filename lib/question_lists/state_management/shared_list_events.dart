/// Everything that can happen on the `/shared/<code>` screen.
sealed class SharedListEvent {}

/// Load (or reload) the preview. Dispatched once when the screen appears and
/// again by the retry button.
class SharedListStarted extends SharedListEvent {}

/// "Save to my lists" pressed. Signed in → create the copy; signed out →
/// remember the code and ask to sign in.
class SharedListSaveRequested extends SharedListEvent {}

/// The screen reacted to the one-shot flags (navigated, showed the snackbar).
class SharedListImportHandled extends SharedListEvent {}

/// Internal: the session became authenticated while the screen is open — if
/// the visitor had asked to save this list before signing in, finish it now.
class SharedListSignedIn extends SharedListEvent {}
