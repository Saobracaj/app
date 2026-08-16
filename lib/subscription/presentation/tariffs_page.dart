import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../core/di.dart';
import '../../core/responsive.dart';
import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';
import 'pending_order_card.dart';
import 'tariff_formatting.dart';

/// Витрина тарифов: две колонки (базовый / с русским) по три срока.
///
/// Экран существует **только в вебе** — маршрут зарегистрирован под `kIsWeb`
/// (см. `lib/routes.dart`). В мобильных сборках подписка не упоминается вообще:
/// App Store 3.1.3(b) не разрешает ни цен, ни ссылок на внешнюю оплату.
class TariffsPage extends StatelessWidget {
  const TariffsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SubscriptionBloc>(),
      child: Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.subscription_tariffsTitle.tr())),
        body: BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, state) {
            if (state.inProgress && state.tariffs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.tariffs.isEmpty) {
              return _LoadFailed(
                message: state.errorMessage,
                onRetry: () => context.read<SubscriptionBloc>().add(
                  SubscriptionRequested(),
                ),
              );
            }
            return ReadableWidth(
              maxWidth: 900,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Уже созданный заказ — сверху: человек вернулся доплатить,
                  // а не выбрать второй тариф.
                  if (state.pendingOrder != null) ...[
                    PendingOrderCard(order: state.pendingOrder!),
                    const SizedBox(height: 16),
                  ],
                  _TariffColumns(state: state),
                  const SizedBox(height: 24),
                  const _FreeTierCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Две колонки тарифов: базовый и с русским контентом. На узком экране —
/// одна под другой.
class _TariffColumns extends StatelessWidget {
  const _TariffColumns({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (final kind in TariffKind.values)
        _TariffColumn(
          kind: kind,
          tariffs: [
            for (final t in state.tariffs)
              if (t.kind == kind) t,
          ]..sort((a, b) => a.months.compareTo(b.months)),
          submitting: state.submitting,
        ),
    ];
    if (!context.isMediumScreen) {
      return Column(
        children: [
          for (final column in columns) ...[
            column,
            const SizedBox(height: 16),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: columns[i]),
        ],
      ],
    );
  }
}

class _TariffColumn extends StatelessWidget {
  const _TariffColumn({
    required this.kind,
    required this.tariffs,
    required this.submitting,
  });

  final TariffKind kind;
  final List<Tariff> tariffs;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tariffKindName(kind), style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              tariffKindSummary(kind),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final tariff in tariffs) ...[
              _TariffRow(
                tariff: tariff,
                // Годовой — основной срок: он и выделен.
                highlighted: tariff.months == 12,
                submitting: submitting,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TariffRow extends StatelessWidget {
  const _TariffRow({
    required this.tariff,
    required this.highlighted,
    required this.submitting,
  });

  final Tariff tariff;
  final bool highlighted;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authenticated = context.select(
      (AuthBloc bloc) => bloc.state.isAuthenticated,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: highlighted
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      monthsLabel(tariff.months),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (highlighted) ...[
                      const SizedBox(width: 8),
                      _BestBadge(),
                    ],
                  ],
                ),
                Text(
                  priceLabel(tariff.priceRsd),
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  LocaleKeys.subscription_perMonth.tr(
                    args: ['${tariff.pricePerMonth.round()}'],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (authenticated)
            FilledButton(
              onPressed: submitting
                  ? null
                  : () => context.read<SubscriptionBloc>().add(
                      OrderRequested(tariff.sku),
                    ),
              child: Text(LocaleKeys.subscription_choose.tr()),
            )
          else
            TextButton(
              onPressed: () => Routemaster.of(context).push('/login'),
              child: Text(LocaleKeys.subscription_signInToBuy.tr()),
            ),
        ],
      ),
    );
  }
}

class _BestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        LocaleKeys.subscription_best.tr(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// Что открыто без подписки — три категории целиком плюс всё, что бесплатно
/// всегда. Стоит на витрине, чтобы человек не платил за то, что и так его.
class _FreeTierCard extends StatelessWidget {
  const _FreeTierCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.subscription_freeTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.subscription_freeBody.tr(),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message ?? LocaleKeys.subscription_loadFailed.tr()),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(LocaleKeys.subscription_retry.tr()),
          ),
        ],
      ),
    );
  }
}
