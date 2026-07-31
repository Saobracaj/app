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
import 'auth/state_management/auth_cubit.dart';
import 'core/di.dart';
import 'generated/codegen_loader.g.dart';
import 'session/session_resume_gate.dart';
import 'session/session_route_observer.dart';
import 'theme/state_management/theme_cubit.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  configureDependencies();
  await initFirebase();
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AllQuestionsBloc()..add(Load())),
        BlocProvider(create: (context) => PurchaseBloc()),
        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(create: (context) => getIt<AuthCubit>()..bootstrap()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => SessionResumeGate(
              delegate: _routerDelegate,
              child: child ?? const SizedBox.shrink(),
            ),
            routerDelegate: _routerDelegate,
            routeInformationParser: RoutemasterParser(),
            title: 'Saobraćaj',
            themeMode: themeState.mode,
            theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: themeState.seedColor),
              textTheme: GoogleFonts.interTextTheme(),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeState.seedColor,
                brightness: Brightness.dark,
              ),
              textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            ),
          );
        },
      ),
    );
  }
}
