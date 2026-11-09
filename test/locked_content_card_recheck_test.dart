import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/subscription/presentation/paywall.dart';

/// Считает, с какими причинами карточка просила перепроверить гранты.
class _CountingFlags extends FeatureFlagsRepository {
  _CountingFlags() : super(GraphqlClient(TokenStorage()), TokenStorage());

  final reasons = <String>[];

  @override
  Future<void> refreshIfStale({
    required String reason,
    Duration maxAge = FeatureFlagsRepository.staleAfter,
  }) async {
    reasons.add(reason);
  }
}

Widget _card() => const Scaffold(
  body: LockedContentCard(
    source: PaywallSource.konspekt,
    title: 'Заперто',
    body: 'Нужен пропуск',
    categoryId: '30',
  ),
);

/// Замок рисуется по кэшу грантов; показанная карточка — повод сверить кэш с
/// бэкендом, чтобы отставший кэш исправился там, где его видит пользователь.
void main() {
  testWidgets('показанная карточка замка просит перепроверить гранты', (
    tester,
  ) async {
    final flags = _CountingFlags();
    final bloc = FeatureFlagsBloc(flags);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(home: BlocProvider.value(value: bloc, child: _card())),
    );
    await tester.pump();

    expect(flags.reasons, ['locked_content']);

    // Перестроения карточки новых просьб не рождают — только первый показ.
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: BlocProvider.value(value: bloc, child: _card())),
    );
    await tester.pump();
    expect(flags.reasons, ['locked_content']);
  });

  testWidgets('без держателя флагов карточка просто рисуется', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _card()));
    await tester.pump();

    expect(find.text('Заперто'), findsOneWidget);
    expect(find.text('Нужен пропуск'), findsOneWidget);
  });
}
