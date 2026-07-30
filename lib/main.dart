import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/routes.dart';
import 'package:saobracaj/state_management/all_questions_bloc.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:saobracaj/state_management/purchase_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth/data/auth_repository.dart';
import 'auth/data/graphql_client.dart';
import 'auth/data/token_storage.dart';
import 'auth/state_management/auth_cubit.dart';
import 'generated/codegen_loader.g.dart';
import 'theme/theme_cubit.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = TokenStorage();
    final authRepository = AuthRepository(GraphqlClient(storage), storage);
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AllQuestionsBloc()..add(Load())),
        BlocProvider(create: (context) => PurchaseBloc()),
        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(
          create: (context) => AuthCubit(authRepository)..bootstrap(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            debugShowCheckedModeBanner: false,
            routerDelegate:
                RoutemasterDelegate(routesBuilder: (context) => routes),
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
