import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

import 'auth/data/auth_repository.dart';
import 'auth/data/firebase_init.dart';
import 'auth/state_management/auth/auth_bloc.dart';
import 'auth/state_management/auth/auth_events.dart';
import 'core/app_language.dart';
import 'core/deep_links/deep_link_path.dart';
import 'core/deep_links/deep_link_service.dart';
import 'core/di.dart';
import 'db/dependencies.dart';
import 'feature_flags/presentation/russian_content_prompt.dart';
import 'feature_flags/state_management/feature_flags_bloc.dart';
import 'feature_flags/state_management/feature_flags_events.dart';
import 'groups/presentation/groups_error_listener.dart';
import 'groups/state_management/groups_bloc.dart';
import 'groups/state_management/groups_events.dart';
import 'notifications/data/push_token_service.dart';
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
    final state = routeInformation.state;
    if (state is Map && state[_sessionKey] != _session) {
      return super.parseRouteInformation(RouteInformation(uri: uri));
    }
    return super.parseRouteInformation(routeInformation);
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

  StreamSubscription<String>? _deepLinks;

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
  }

  void _openDeepLink(String path) => _routerDelegate.push(path);

  @override
  void dispose() {
    _deepLinks?.cancel();
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
        BlocProvider(create: (context) => AllQuestionsBloc()..add(Load())),
        BlocProvider(create: (context) => PurchaseBloc()),
        BlocProvider(create: (context) => ThemeBloc()),
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
          return MaterialApp.router(
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
