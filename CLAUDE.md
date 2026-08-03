# app/ — Flutter client

Serbian traffic-exam trainer. Quiz content ships as bundled JSON assets; user answer history and stats are persisted locally via Drift (SQLite).

## Code generation is required after editing generated-source inputs

`./codegen.sh` runs, in order:
1. `easy_localization:generate` — builds `LocaleKeys` and `CodegenLoader` from `assets/translations/*.json`.
2. `build_runner build --delete-conflicting-outputs` — regenerates Freezed (`*.freezed.dart`), json_serializable (`*.g.dart`), Drift (`db.dart` companions), and **injectable** DI registrations (`lib/core/di.config.dart`).

Editing translations, `@freezed` models, Drift tables, or `@injectable`/`@module` DI annotations **without** re-running codegen will leave stale generated files and break the build. Never hand-edit generated files.

## State-management conventions (follow these for all UI work)

The app is standardized on a single pattern. New code must follow it; touch old code toward it when you're in the file.

1. **Widgets are `StatelessWidget`.** UI holds no mutable state and no business logic — it reads state from a Bloc and dispatches events. The *only* exception is a genuinely trivial widget whose state is one or two purely-visual, logic-free fields (e.g. a hover/expand toggle, an animation controller). When in doubt, use a Bloc. Don't reach for `StatefulWidget` + `setState` to drive a form or a feature — that's what a Bloc is for.
2. **One Bloc per screen/feature, as a trio of files** under `<feature>/state_management/`:
   - `x_state.dart` — `@freezed` class `XState` with `@Default(...)` fields (`inProgress`, `errorMessage`, form values, …) and `copyWith`.
   - `x_events.dart` — `sealed class XEvent {}` plus one concrete subclass per user action (`SubmitPressed`, `EmailChanged`, `TogglePasswordVisibility`, …).
   - `x_bloc.dart` — `class XBloc extends Bloc<XEvent, XState>` registering `on<Event>(_reducer)` handlers in the constructor. Annotate with `@injectable`.

   **Always use `Bloc` (events) — there are no `Cubit`s in the app.** The app-wide session holder is `AuthBloc` (`lib/auth/state_management/auth/`), which subscribes to the session stream published by `AuthRepository`; theme is `ThemeBloc`. Don't introduce a `Cubit` — model the state as a `Bloc` with events.
3. **DI via `getIt` (injectable).** A Bloc that depends on services (repositories, clients) is `@injectable` and resolved with `getIt<XBloc>()` — pass screen-specific values through `@factoryParam` (e.g. `getIt<ConfirmCodeBloc>(param1: email)`). A Bloc built purely from runtime/screen values with no injected services may be constructed directly in `BlocProvider(create:)` (e.g. `QuestContentBloc(choices, answers, id)`). Repositories / data sources / clients are always `@lazySingleton` and **never** hand-constructed in widget code; third-party objects (e.g. `Dio`) come from a `@module`. Registrations are generated — run codegen after changing annotations.
4. **Wiring in the widget tree:** `BlocProvider(create: (_) => getIt<XBloc>())` (optionally `..add(InitEvent())`), then `BlocBuilder` / `BlocListener` / `BlocConsumer` to render and to react to one-shot effects (navigation, snackbars). Surface field errors inline via the shared `ErrorField` widget, not `SnackBar`.

**Canonical example:** `lib/auth/` — the login/register/reset/confirm screens are the reference implementation (stateless pages + Bloc trio + `getIt`). `lib/test/quest/comment/state_management/comment_bloc.dart` is a minimal single-Bloc example.

## Folder layout (feature-first)

Each feature owns a folder under `lib/` with these sub-layers (create only what the feature needs):

```
lib/<feature>/
  presentation/       # StatelessWidget pages & widgets
  state_management/    # x_bloc.dart, x_events.dart, x_state.dart (+ *.freezed.dart)
  data/                # repositories, data sources, GraphQL, DTOs
  models/ | domain/    # freezed models / entities
lib/core/              # cross-cutting: di.dart, shared widgets, base clients
```

Blocs never live loose in a feature root or inline in a widget file, and `lib/state_management/` (the old flat bucket) is not used — every Bloc sits in its feature's `state_management/`.
