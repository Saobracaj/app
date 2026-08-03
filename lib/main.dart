import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/questions/state_management/all_questions_bloc.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:saobracaj/purchase/state_management/purchase_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'theme/state_management/theme_bloc.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  configureDependencies();
  await initFirebase();
  // Load persisted feature toggles / cached premium grants and refresh from the
  // backend if a session exists.
  await featureFlags.bootstrap();
  // Start syncing the device's FCM push token once a session is available.
  getIt<PushTokenService>().start();
  runApp(
    EasyLocalization(
      useOnlyLangCode: true,
      supportedLocales: [Locale('ru'), Locale('en'), Locale('sr')],
      fallbackLocale: Locale('ru'),
      path: 'assets/translations',
      assetLoader: CodegenLoader(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              // The "default" accent uses the platform dynamic palette when
              // available (Android 12+); every explicit swatch — and any
              // platform without dynamic colors — falls back to a seeded scheme.
              final useDynamic = themeState.isDefaultAccent;
              final lightScheme = useDynamic && lightDynamic != null
                  ? lightDynamic.harmonized()
                  : ColorScheme.fromSeed(seedColor: themeState.seedColor);
              final darkScheme = useDynamic && darkDynamic != null
                  ? darkDynamic.harmonized()
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
                theme: ThemeData(
                  colorScheme: lightScheme,
                  textTheme: GoogleFonts.interTextTheme(),
                ),
                darkTheme: ThemeData(
                  colorScheme: darkScheme,
                  textTheme:
                      GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
