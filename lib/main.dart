import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saobracaj/purchase/state_management/purchase_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth/data/auth_repository.dart';
import 'auth/data/firebase_init.dart';
import 'auth/state_management/auth/auth_bloc.dart';
import 'auth/state_management/auth/auth_events.dart';
import 'core/analytics/analytics_service.dart';
import 'core/app_language.dart';
import 'core/deep_links/deep_link_path.dart';
import 'core/deep_links/deep_link_service.dart';
import 'core/di.dart';
import 'core/network/network_status.dart';
import 'core/network/state_management/network_status_bloc.dart';
import 'core/network/state_management/network_status_events.dart';
import 'db/dependencies.dart';
import 'feature_flags/presentation/russian_content_prompt.dart';
import 'feature_flags/state_management/feature_flags_bloc.dart';
import 'feature_flags/state_management/feature_flags_events.dart';
import 'groups/presentation/groups_error_listener.dart';
import 'groups/state_management/groups_bloc.dart';
import 'groups/state_management/groups_events.dart';
import 'notifications/data/push_message.dart';
import 'notifications/data/push_message_service.dart';
import 'notifications/data/push_token_service.dart';
import 'notifications/presentation/push_message_snackbar.dart';
import 'question_lists/presentation/question_lists_error_listener.dart';
import 'question_lists/state_management/question_lists_bloc.dart';
import 'test/data/quiz_preferences_repository.dart';
import 'question_lists/state_management/question_lists_events.dart';
import 'generated/codegen_loader.g.dart';
import 'theme/app_theme.dart';
import 'theme/state_management/theme_bloc.dart';

/// The light and dark [ColorScheme]s of the platform's dynamic (Material You)
/// palette, or `null` where there is none (iOS, web, Android < 12).
///
/// Resolved once, before [runApp]: the plugin only answers asynchronously, so
/// querying it from inside the widget tree (`DynamicColorBuilder`) makes the
/// first frames render with the fallback seeded scheme and then visibly snap
/// to the dynamic palette ~a second later — worse on every hot restart.
Future<({ColorScheme light, ColorScheme dark})?> _resolveDynamicSchemes() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return null;
    return (
      light: palette.toColorScheme().harmonized(),
      dark: palette.toColorScheme(brightness: Brightness.dark).harmonized(),
    );
  } on PlatformException {
    return null;
  }
}

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final dynamicSchemes = await _resolveDynamicSchemes();
  await EasyLocalization.ensureInitialized();
  // DateFormat throws for sr/ru until their symbol tables are loaded;
  // easy_localization does not do this on its own.
  await initializeDateFormatting();
  configureDependencies();
  // Subscribe to the platform's connectivity first: the very first requests
  // below (flags, session, push token) already report into this signal, and
  // the home screen reads it on its first frame.
  await getIt<NetworkStatus>().start();
  await initFirebase();
  // Instantiate the session holder before anything issues an authenticated
  // request: it subscribes to the GraphQL client's `sessionExpired` signal, so
  // an unrenewable session signs the user out no matter which call hit it first.
  getIt<AuthRepository>();
  // Load persisted feature toggles / cached premium grants and refresh from the
  // backend if a session exists.
  await featureFlags.bootstrap();
  // Load the run options and the per-question tab the user picked last time, so
  // the setup screens and the question tabs render them on their first frame.
  await getIt<QuizPreferencesRepository>().bootstrap();
  // Start syncing the device's FCM push token once a session is available.
  getIt<PushTokenService>().start();
  // And listen for the notifications themselves: the ones tapped in the tray
  // (opened as links) and the ones arriving while the app is on screen (shown
  // as a snackbar). Before the first frame, so a cold start from a
  // notification does not miss the message that started it.
  getIt<PushMessageService>().start();
  // Listen for invite links before the first frame: a cold start from a link
  // must not miss the link that started it (DeepLinkService holds it until the
  // router exists).
  await getIt<DeepLinkService>().start();
  runApp(
    EasyLocalization(
      useOnlyLangCode: true,
      // Use the real CLDR plural rules (sr: 2 → few, 5 → other); the default
      // maps 2 to the literal "two" case, which Slavic languages don't have.
      ignorePluralRules: false,
      supportedLocales: [Locale('ru'), Locale('en'), Locale('sr')],
      fallbackLocale: Locale('ru'),
      path: 'assets/translations',
      assetLoader: CodegenLoader(),
      child: MyApp(dynamicSchemes: dynamicSchemes),
    ),
  );
}

/// [RoutemasterParser] that survives being handed a full URL, and browser
/// history entries left over from an earlier run of the app.
///
/// The engine's built-in deep-link handling (and any other system source) may
/// push `https://saobracaj.gleb.at/question/7923` as route information verbatim;
/// routemaster would take the whole string for a path and land on "page not
/// found". A link with a scheme is therefore normalized through the same
/// [deepLinkPathFor] the DeepLinkService uses. Not on the web — there the
/// address bar is the router's input and never carries a scheme.
///
/// The second job matters on the web, where history entries outlive the run of
/// the app that wrote them — see [_session].
class AppRouteInformationParser extends RoutemasterParser {
  AppRouteInformationParser();

  /// Identifies this run of the app inside the browser history entries it
  /// writes.
  ///
  /// Routemaster stores the index of its own chronological history in every
  /// history entry, and navigates the back/forward buttons by that index. The
  /// index only means something to the run that wrote it: reloading the page
  /// (F5, or following a link back into the app) starts a fresh, empty
  /// history, while the entries behind the current one still carry the indexes
  /// of the previous run. Handing those to routemaster made it look up a
  /// chronological entry that no longer exists — back and forward then either
  /// did nothing or jumped to an unrelated screen, and the history stack was
  /// mangled on the way.
  ///
  /// So every entry is stamped with the session that wrote it, and an entry
  /// from another session is navigated by its URL instead — which is what the
  /// address bar shows anyway, and what a typed-in link does. As the user walks
  /// over such an entry it gets rewritten with this session's stamp.
  final String _session = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  Future<RouteData> parseRouteInformation(RouteInformation routeInformation) {
    final uri = routeInformation.uri;
    if (!kIsWeb && uri.hasScheme) {
      final path = deepLinkPathFor(uri) ?? '/';
      return super.parseRouteInformation(
        RouteInformation(uri: Uri.parse(path)),
      );
    }
    final state = normalizeHistoryState(routeInformation.state);
    if (state is Map && state[_sessionKey] != _session) {
      return super.parseRouteInformation(RouteInformation(uri: uri));
    }
    return super.parseRouteInformation(
      RouteInformation(uri: uri, state: state),
    );
  }

  @override
  RouteInformation restoreRouteInformation(RouteData configuration) {
    final info = super.restoreRouteInformation(configuration);
    final state = info.state;
    return RouteInformation(
      uri: info.uri,
      state: {
        if (state is Map) ...state.cast<String, Object?>(),
        _sessionKey: _session,
      },
    );
  }

  static const _sessionKey = 'appSession';
}

/// Приводит состояние истории браузера к типам, которые ожидает routemaster.
///
/// Всё, что уходит в `history.pushState`, возвращается оттуда уже как
/// JS-объект, и движок разбирает его обратно в Dart. В JS-сборке это проходит
/// незаметно: там `Map<dynamic, dynamic>` подходит под `Map<String, dynamic>`,
/// а int и double — вообще одно и то же. В wasm-сборке (`flutter build web
/// --wasm`, ею собирается прод) типы настоящие: карта возвращается как
/// `Map<Object?, Object?>`, а числа — как `double`. Жёсткие приведения внутри
/// `RouteData.fromRouteInformation` (`as Map<String, dynamic>`,
/// `as int?`) на этом падают с «Runtime type check failed», разбор адреса
/// обрывается — и кнопки «назад/вперёд» перестают работать: адресная строка
/// ходит по истории, а приложение остаётся на прежнем экране.
///
/// Именно поэтому поломка была только в Chrome: WasmGC поддерживают Chrome и
/// Edge, а Firefox получает ту же сборку в JS-варианте, где приведения типов
/// проходят.
Object? normalizeHistoryState(Object? state) {
  if (state is Map) {
    return <String, dynamic>{
      for (final entry in state.entries)
        '${entry.key}': normalizeHistoryState(entry.value),
    };
  }
  if (state is List) {
    return [for (final value in state) normalizeHistoryState(value)];
  }
  // Целые числа возвращаются из истории как double — routemaster ждёт int.
  if (state is double && state.isFinite && state == state.roundToDouble()) {
    return state.toInt();
  }
  return state;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.dynamicSchemes});

  /// See [_resolveDynamicSchemes]; `null` means "no dynamic colors here".
  final ({ColorScheme light, ColorScheme dark})? dynamicSchemes;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final RoutemasterDelegate _routerDelegate = RoutemasterDelegate(
    routesBuilder: (context) => routes,
  );

  /// Held for the lifetime of the app: it stamps the browser history entries
  /// with the session that wrote them, so it must not be rebuilt with the tree.
  final AppRouteInformationParser _routeInformationParser =
      AppRouteInformationParser();

  /// Shows the foreground-notification snackbar above whatever screen is open;
  /// the app root has no `Scaffold` of its own to ask.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<String>? _deepLinks;
  StreamSubscription<PushMessage>? _pushOpened;
  StreamSubscription<PushMessage>? _pushForeground;

  @override
  void initState() {
    super.initState();
    final service = getIt<DeepLinkService>();
    _deepLinks = service.paths.listen(_openDeepLink);
    // The link the app was launched with, if any. Pushed after the first frame
    // so the router is attached to a navigator by the time it arrives.
    final pending = service.takePending();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDeepLink(pending));
    }
    // Push notifications, the same way: a tapped one is a link to open, a
    // foreground one is shown as a snackbar. Both need the router and the
    // messenger to be attached, hence after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pushes = getIt<PushMessageService>();
      _pushOpened = pushes.opened.listen(_openPushMessage);
      _pushForeground = pushes.foreground.listen(_showPushMessage);
      final pendingPush = pushes.takePendingOpen();
      if (pendingPush != null) _openPushMessage(pendingPush);
    });
    // Screen tracking: the delegate notifies on every navigation, and the
    // service collapses repeats of the same (templated) screen. The
    // post-frame call reports the screen the app started on, which precedes
    // the listener's first notification.
    _routerDelegate.addListener(_logScreenView);
    WidgetsBinding.instance.addPostFrameCallback((_) => _logScreenView());
  }

  void _logScreenView() {
    final path = _routerDelegate.currentConfiguration?.path;
    if (path != null) analytics.logScreenView(path);
  }

  void _openDeepLink(String path) => _routerDelegate.push(path);

  /// The link of a tapped notification (or of the snackbar's «go» button):
  /// one of ours opens in-app, through the same route mapping as an external
  /// deep link; anything else is handed to the browser.
  void _openPushMessage(PushMessage push) {
    final uri = push.link;
    if (uri == null) return;
    final path = deepLinkPathFor(uri);
    if (path != null) {
      _routerDelegate.push(path);
      return;
    }
    unawaited(
      launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object e) {
        debugPrint('Push link could not be opened: $uri ($e)');
        return false;
      }),
    );
  }

  void _showPushMessage(PushMessage push) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      buildPushMessageSnackBar(
        push,
        // The action dismisses the snackbar on its own.
        onOpen: push.link == null ? null : () => _openPushMessage(push),
      ),
    );
  }

  @override
  void dispose() {
    _deepLinks?.cancel();
    _pushOpened?.cancel();
    _pushForeground?.cancel();
    _routerDelegate.removeListener(_logScreenView);
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mirror the active UI locale onto the header sent with every GraphQL
    // request, so the backend keeps the stored user language in sync.
    appLanguageCode = context.locale.languageCode;
    return MultiBlocProvider(
      providers: [
        // Not lazy: the question bank is read by the simulation, the quiz and
        // the statistics, none of which is on the home screen. Loading it on
        // the first `context.read` meant the first "start simulation" from a
        // cold start ran into `questionsData == null` and a grey screen —
        // whether it worked depended on which tab the user had opened before.
        BlocProvider(
          lazy: false,
          create: (context) => AllQuestionsBloc()..add(Load()),
        ),
        BlocProvider(create: (context) => PurchaseBloc()),
        BlocProvider(create: (context) => ThemeBloc()),
        // Online/offline for the widget tree (offline card on the home screen,
        // "no network" copy). Blocs that reload on reconnect listen to the
        // `NetworkStatus` service directly.
        BlocProvider(
          create: (context) =>
              getIt<NetworkStatusBloc>()..add(const NetworkStatusStarted()),
        ),
        BlocProvider(
          create: (context) => getIt<AuthBloc>()..add(AuthBootstrapRequested()),
        ),
        BlocProvider(
          create: (context) =>
              FeatureFlagsBloc(featureFlags)..add(FeatureFlagsStarted()),
        ),
        // App-wide so the home-screen row, the list screen and the "add to
        // list" menu on the question screen share one state.
        BlocProvider(
          create: (context) =>
              getIt<QuestionListsBloc>()..add(QuestionListsStarted()),
        ),
        // App-wide as well: the home-screen cards and the group screen read one
        // list, and membership changes have to reach both.
        BlocProvider(
          create: (context) => getIt<GroupsBloc>()..add(const GroupsStarted()),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          // The "default" accent uses the platform dynamic palette when
          // available (Android 12+); every explicit swatch — and any
          // platform without dynamic colors — falls back to a seeded scheme.
          final dynamicSchemes = widget.dynamicSchemes;
          final useDynamic = themeState.isDefaultAccent && dynamicSchemes != null;
          final lightScheme = useDynamic
              ? dynamicSchemes.light
              : ColorScheme.fromSeed(seedColor: themeState.seedColor);
          final darkScheme = useDynamic
              ? dynamicSchemes.dark
              : ColorScheme.fromSeed(
                  seedColor: themeState.seedColor,
                  brightness: Brightness.dark,
                );
          // `intl` форматирует числа и даты по своей глобальной локали, а не по
          // локали Flutter: без этой строки `DateFormat`/`NumberFormat` молча
          // работают по en_US — русские даты выходят как «Aug 16, 2026», а
          // суммы с запятой вместо пробела.
          Intl.defaultLocale = context.locale.toLanguageTag();
          return MaterialApp.router(
            scaffoldMessengerKey: _messengerKey,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => QuestionListsErrorListener(
              child: GroupsErrorListener(
                // Above the router, so the one-time question about Russian
                // materials covers whatever screen the app started on.
                child: RussianContentPrompt(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
            routerDelegate: _routerDelegate,
            routeInformationParser: _routeInformationParser,
            title: 'Saobraćaj',
            themeMode: themeState.mode,
            theme: buildAppTheme(lightScheme),
            darkTheme: buildAppTheme(darkScheme),
          );
        },
      ),
    );
  }
}
