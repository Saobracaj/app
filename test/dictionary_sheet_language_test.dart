import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/test/quest/presentation/quest_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Флаги с зафиксированным ответом на вопрос о русскоязычном контенте. Грант не
/// выдаём: словарь терминов бесплатен, решает именно выбор пользователя.
class _StubFlags extends FeatureFlagsRepository {
  _StubFlags({required this.russian})
    : super(GraphqlClient(TokenStorage()), TokenStorage());

  final bool russian;

  @override
  FeatureFlagsSnapshot get snapshot => FeatureFlagsSnapshot.resolve(
    localOverrides: {AppFeature.russianContent.key: russian},
    grants: const {},
    authenticated: false,
  );

  @override
  Stream<FeatureFlagsSnapshot> get changes => Stream.value(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Фрагменты определения термина «Насеље» на обоих языках.
  const srFragment = 'функционално обједињен простор';
  const ruFragment = 'функционально объединенное пространство';

  Widget wrap({required bool russian}) => MaterialApp(
    home: BlocProvider(
      create: (_) => FeatureFlagsBloc(_StubFlags(russian: russian)),
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMarkdown(context, 'Насеље'),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('без русскоязычного контента определение только на сербском', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(russian: false));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining(srFragment), findsOneWidget);
    expect(find.textContaining(ruFragment), findsNothing);
  });

  testWidgets('с русскоязычным контентом показываются оба определения', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(russian: true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining(srFragment), findsOneWidget);
    expect(find.textContaining(ruFragment), findsOneWidget);
  });
}
