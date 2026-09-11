# app/ — Flutter client

Serbian traffic-exam trainer. Quiz content ships as bundled JSON assets; user answer history and stats are persisted locally via Drift (SQLite).

## Shipping

One pipeline builds all three targets — `.github/workflows/build-and-deploy.yml`
(Android APK/AAB, iOS IPA → TestFlight, web → GHCR image → VPS). Which secrets it
needs, where to get them, and how to turn the Google Play upload back on is in
**`docs/ci-cd.md`**. Every store/web build must pass `--target lib/main_prod.dart`
— without it the app runs the debug flavor and talks to `http://localhost:8080`.

## Code generation is required after editing generated-source inputs

`./codegen.sh` runs, in order:
1. `easy_localization:generate` — builds `LocaleKeys` and `CodegenLoader` from `assets/translations/*.json`.
2. `build_runner build --delete-conflicting-outputs` — regenerates Freezed (`*.freezed.dart`), json_serializable (`*.g.dart`), Drift (`db.dart` companions), and **injectable** DI registrations (`lib/core/di.config.dart`).

Editing translations, `@freezed` models, Drift tables, or `@injectable`/`@module` DI annotations **without** re-running codegen will leave stale generated files and break the build. Never hand-edit generated files.

## `assets/question_analytics.json` is derived — regenerate it, don't edit it

The question screen's "Анализа" tab is driven by a computed asset, not by
hand-written content. `tool/question_analytics.py` builds it from
`assets/practice.json` (699 real exam variants) and `assets/allQuestions.json`,
and nothing else:

```bash
python3 tool/question_analytics.py --verify   # --verify prints the model checks
```

**Re-run it after any change to either of those two assets.**
`test/question_analytics_test.dart` fails when the asset and its inputs have
drifted apart, so a forgotten regeneration is caught rather than shipped as
stale percentages.

What it computes, and why the numbers are trustworthy: the exam's blueprint is
reverse-engineered from the sample (every variant is 41 questions with the same
category profile; each subcategory pool contributes a fixed number of slots,
drawn uniformly — verified by a chi-square test per pool), so a question's
probability is `slots / pool size` rather than its raw frequency in a sample far
too small for 1559 separate estimates. Summed over the bank the model reproduces
a real exam to three decimals — 41.000 questions and 98.11 points against an
actual 98.12. The bank holds only what the B exam can draw: the 142 questions of
category 38 ("последице непоштовања прописа", an area that belongs to the C/D
test and appears in none of the 699 variants) were removed, so every question
now has a non-zero chance. The keyword block ("Ключевые фразы") is built the same way and
reports only *absolute* cues — whole answers or phrases that are correct (or
wrong) in every question of the bank where they occur, and "word in the
question → this answer" links; nothing "mostly", no option-length or
stem-echo heuristics. Cues are computed on the **Serbian** text only and shown
as such in every interface language: the exam is sat in Serbian, the options on
screen are Serbian, and `allQuestions_ru.json` is a reading aid, not a corpus
(the operator asked for this explicitly). The one figure it *cannot* produce is how hard a
question is for other people; that comes from `questionDifficulty` in
`saobracaj_backend`.

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

## Offline / network failures (follow this for every remote section)

The app must stay usable without a connection (questions and the exam
simulation are bundled assets), and going offline is *expected*, not an error
to announce. The building blocks live in `lib/core/network/`:

- `NetworkStatus` (registered in `RegisterModule`, started in `main()`): the
  app-wide online/offline signal — platform connectivity (`connectivity_plus`)
  plus the GraphQL client's own transport outcomes (`reportFailure` /
  `reportSuccess`), with a periodic probe while the link is up but the server
  was unreachable. `NetworkStatusBloc` republishes it to the widget tree
  (`context.select<NetworkStatusBloc, bool>((b) => b.state.online)`).
- A Bloc that loads remote data keeps a `failed` flag (plus `failedOffline` /
  `offline` when the copy differs), renders it inline with the shared
  `LoadFailedView` (`lib/core/presentation/load_failed_view.dart`) and
  subscribes to `NetworkStatus.onReconnected` to reload **by itself** — no
  snackbar for a failed *load*. Snackbars are for failed *user actions* only.
- Never show `GraphqlException.message` for a network failure (it is an English
  placeholder — the "Network error" toast the operator kept seeing): pass errors
  through `describeError(e)` / `describeActionError(e)` / `isNetworkError(e)`
  (`lib/core/network/error_messages.dart`). `describeError` is the copy for the
  inline "could not load" block (`network.noConnection`);
  `describeActionError` is the copy for a snackbar after something the user
  pressed (`network.actionFailedOffline`). `'$e'` in a state's `errorMessage`
  is always a bug.
- **A failed load never raises a snackbar** — only a failed *action* does. A
  load reports itself through `failed` / `failedOffline` in the state, and the
  screen renders `LoadFailedView` / `LoadFailedList` over it. In particular, a
  failed read must not set `loaded`: "could not read" is not "there is nothing
  here", and the empty-state copy would lie (this is what made a group's wall
  answer «в группе ещё нет постов» while offline).
- The home screen shows `OfflineHomeCard` (links to questions / simulation)
  instead of per-block retries while offline.

## The subscription is sold in-app, through the stores

`lib/subscription/` sells one thing, and it sells it through the App Store and
Google Play — never through a web checkout, and never by linking to one from
inside the app (both stores forbid it).

- **`StorePurchaseService` is the only place that touches `in_app_purchase`.**
  There is no web implementation of that plugin: `InAppPurchase.instance`
  throws in the browser, so every method of the service checks `isSupported`
  first, and the rest of the app asks `bloc.storePlatform` (`null` in the web
  build) rather than `kIsWeb`. In the web build the tariffs screen shows the
  same prices as reference figures and points at the app.
- **The result of a purchase arrives on the purchase *stream*, not from
  `buy()`.** A store also hands over receipts nobody asked for right now — a
  restore, a deferred payment that finally cleared, a purchase made on another
  device — so `SubscriptionBloc` listens for the whole time it is alive.
- **Confirm to the store last.** The order is: receipt → `redeemStorePurchase`
  on the backend → `refreshGrants()` → `complete()`. An unconfirmed purchase is
  refunded by Google after three days, which is the right outcome when the
  entitlement could not be written; confirming first would eat the money.
- **Prices come from the store.** `Tariff.priceRsd` is the *reference* price
  for the web shop window; on a phone the localised `StoreProduct.price` is
  what is shown. The two are kept in step by hand — see
  `saobracaj_backend/BILLING.md`, which also lists the store console setup.
- Only the monthly tariffs auto-renew. Everything the UI says about renewal
  hangs off `Tariff.autoRenewing` / `SubscriptionStatus.autoRenewing`: a date
  on an auto-renewing subscription is the next charge, not the end of access,
  and cancelling is only possible in the store (`manageUrl`).

## GraphQL queries are batched — a fake server must not assume one operation per request

`GraphqlClient` merges the *queries* that pile up while another request is in
flight into a single document (`lib/auth/data/graphql_batch.dart`): opening a
screen wakes several Blocs at once, and they used to spend a round trip each.
Nothing is ever delayed for the sake of a batch — with the line idle a query
goes out immediately, so a chain of dependent requests is exactly as fast as
before. Mutations never batch, and identical queries collected in one round are
asked once.

Two consequences worth knowing:

- **Call sites need no change.** A batched query is namespaced (`me` travels as
  `_b0_me: me`, `$id` as `$_b0_id`) and split back apart on arrival, so each
  caller gets its own payload and its own errors — an error carrying a `path`
  reaches only the operation it belongs to. When the merged document cannot be
  trusted (an error the server could not attribute, or a payload a neighbour's
  failure nulled), the affected callers are simply re-asked one by one.
- **Test fakes must handle a merged document.** A fake `HttpClientAdapter` that
  picks the operation out of `query` by name will meet `query _Batch` once two
  of the screen's queries overlap. Either answer with the `_bN_`-prefixed keys
  (see `test/graphql_batching_test.dart`), or build the client with
  `batchQueries: false` when the test is about what a single operation puts on
  the wire.
