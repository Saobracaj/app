import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() {
    getIt.registerLazySingleton<KonspektRepository>(() => KonspektRepository());
    getIt.registerFactoryParam<KonspektBloc, String, String?>(
      (categoryId, section) => KonspektBloc(getIt(), categoryId, section),
    );
  });

  Widget wrap(Widget child) {
    // A real (never bootstrapped) FeatureFlagsBloc: guest tier, no grants, so
    // the premium-gated dictionary button stays hidden — enough for rendering.
    final flags = FeatureFlagsBloc(FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()));
    return MaterialApp(
      home: BlocProvider.value(value: flags, child: child),
    );
  }

  testWidgets('KonspektPage renders the category 25 konspekt', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '25')));
    await tester.pumpAndSettle();

    expect(find.text('Основы безопасности дорожного движения'), findsOneWidget);
    // The intro and the first section land in the initial viewport.
    expect(find.textContaining('Кто регулирует и контролирует движение'), findsWidgets);
  });

  testWidgets('KonspektPage deep link scrolls to the requested section', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '25', section: 'popravka-i-prepravka')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Поправка и преправка'), findsWidgets);
  });

  testWidgets('KonspektPage shows an error for a category without a konspekt', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '999')));
    await tester.pumpAndSettle();

    // Without EasyLocalization in the tree tr() falls back to the raw key.
    expect(find.text('konspekt.notFound'), findsOneWidget);
  });
}
