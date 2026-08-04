import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
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
import 'core/di.dart';
import 'db/dependencies.dart';
import 'feature_flags/state_management/feature_flags_bloc.dart';
import 'feature_flags/state_management/feature_flags_events.dart';
import 'notifications/data/push_token_service.dart';
import 'question_lists/presentation/question_lists_error_listener.dart';
import 'question_lists/state_management/question_lists_bloc.dart';
import 'question_lists/state_management/question_lists_events.dart';
import 'generated/codegen_loader.g.dart';
import 'session/session_resume_gate.dart';
import 'session/session_route_observer.dart';
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
  // Start syncing the device's FCM push token once a session is available.
  getIt<PushTokenService>().start();
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

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.dynamicSchemes});

  /// See [_resolveDynamicSchemes]; `null` means "no dynamic colors here".
  final ({ColorScheme light, ColorScheme dark})? dynamicSchemes;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Hoisted so the same delegate drives the router and the resume gate's
  // navigation. The observer mirrors every route change to the back-end.
  final RoutemasterDelegate _routerDelegate = RoutemasterDelegate(
    routesBuilder: (context) => routes,
    observers: [SessionRouteObserver()],
  );

  @override
  void dispose() {
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
              child: SessionResumeGate(
                delegate: _routerDelegate,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            routerDelegate: _routerDelegate,
            routeInformationParser: RoutemasterParser(),
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
