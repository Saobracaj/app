import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/core/di.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/konspekt/data/konspekt_repository.dart';
import 'package:saobracaj/konspekt/models/konspekt.dart';
import 'package:saobracaj/konspekt/presentation/konspekt_page.dart';
import 'package:saobracaj/konspekt/state_management/konspekt_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serves the authored sources from `konspekt_content/` instead of calling the
/// backend, so the page can be rendered without a server.
class _StubKonspektRepository extends KonspektRepository {
  _StubKonspektRepository() : super(GraphqlClient(TokenStorage()));

  @override
  Future<Set<String>> availableCategories() async => {'25'};

  @override
  Future<Konspekt?> load(String categoryId) async {
    final file = File('konspekt_content/$categoryId.json');
    if (!file.existsSync()) return null;
    return Konspekt.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }
}

/// A feature-flags repository reporting fixed premium grants, so a test can
/// render the page both as an entitled user and as one without the entitlement.
class _StubFeatureFlagsRepository extends FeatureFlagsRepository {
  _StubFeatureFlagsRepository(this._grants) : super(GraphqlClient(TokenStorage()), TokenStorage());

  final Set<String> _grants;

  @override
  FeatureFlagsSnapshot get snapshot =>
      FeatureFlagsSnapshot.resolve(localOverrides: const {}, grants: _grants, authenticated: true);

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() {
    getIt.registerLazySingleton<KonspektRepository>(_StubKonspektRepository.new);
    getIt.registerFactoryParam<KonspektBloc, String, String?>(
      (categoryId, section) => KonspektBloc(getIt(), categoryId, section),
    );
  });

  Widget wrap(Widget child, {Set<String> grants = const {'category_summaries'}}) {
    final flags = FeatureFlagsBloc(_StubFeatureFlagsRepository(grants));
    return MaterialApp(
      home: BlocProvider.value(value: flags, child: child),
    );
  }

  testWidgets('KonspektPage renders the category 25 konspekt in Serbian by default', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '25')));
    await tester.pumpAndSettle();

    // Without russian_content the authored Serbian fragment wins, both for the
    // category name and for the section titles below it.
    expect(find.text('Основе безбедности саобраћаја'), findsOneWidget);
    expect(find.textContaining('Ко регулише и ко контролише саобраћај'), findsWidgets);
  });

  testWidgets('KonspektPage shows Russian with the russian_content feature on', (tester) async {
    await tester.pumpWidget(wrap(
      const KonspektPage(categoryId: '25'),
      grants: const {'category_summaries', 'russian_content'},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Основы безопасности дорожного движения'), findsOneWidget);
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

  testWidgets('KonspektPage stays closed without the category_summaries entitlement', (tester) async {
    await tester.pumpWidget(wrap(const KonspektPage(categoryId: '25'), grants: const {}));
    await tester.pumpAndSettle();

    expect(find.text('konspekt.unavailable'), findsOneWidget);
    expect(find.text('Основы безопасности дорожного движения'), findsNothing);
  });
}
