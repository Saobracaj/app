import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/di.dart';
import '../../core/responsive.dart';
import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';
import 'pending_order_card.dart';
import 'tariff_formatting.dart';

/// Раздел аккаунта «Подписка»: текущий тариф, срок действия, неоплаченный
/// заказ и история. Только веб — в мобильных сборках раздела нет вовсе.
class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.subscription_title.tr())),
      body: const SubscriptionContent(),
    );
  }
}

/// Содержимое раздела без «шапки» — на широком экране настройки показывают его
/// в правой панели, на телефоне [SubscriptionPage] добавляет свой AppBar.
class SubscriptionContent extends StatelessWidget {
  const SubscriptionContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SubscriptionBloc>(),
      child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, state) {
          if (state.inProgress) {
            return const Center(child: CircularProgressIndicator());
          }
          return ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (state.errorMessage != null) ...[
                  _ErrorLine(message: state.errorMessage!),
                  const SizedBox(height: 12),
                ],
                _CurrentPlanCard(status: state.subscription),
                if (state.subscription.shouldOfferRenewal) ...[
                  const SizedBox(height: 12),
                  _RenewalBanner(status: state.subscription),
                ],
                if (state.pendingOrder != null) ...[
                  const SizedBox(height: 12),
                  PendingOrderCard(order: state.pendingOrder!),
                ],
                if (state.subscription.active) ...[
                  const SizedBox(height: 12),
                  _RemindersSwitch(status: state.subscription),
                ],
                if (state.periods.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _PeriodsCard(periods: state.periods),
                ],
                if (state.pastOrders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _OrdersCard(orders: state.pastOrders),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!status.active) {
      // Без подписки экран объясняет, что открыто бесплатно, и ведёт к тарифам
      // — иначе «подписки нет» читается как «ничего не работает».
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.subscription_noSubscriptionTitle.tr(),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.subscription_freeBody.tr(),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () => Routemaster.of(context).push('/tariffs'),
                  child: Text(LocaleKeys.subscription_toTariffs.tr()),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.subscription_activeTitle.tr(),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              tariffKindName(status.kind ?? TariffKind.basic),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            if (status.endsAt != null)
              Text(
                LocaleKeys.subscription_activeUntil.tr(
                  args: [formatDate(status.endsAt!)],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            if (status.daysLeft != null)
              Text(
                LocaleKeys.subscription_daysLeft.plural(status.daysLeft!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Плашка «пора продлить» за 14 и за 3 дня до конца. Это веб — про деньги тут
/// можно говорить прямо.
class _RenewalBanner extends StatelessWidget {
  const _RenewalBanner({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent = status.renewalIsUrgent;
    return Card(
      margin: EdgeInsets.zero,
      color: urgent
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                urgent
                    ? LocaleKeys.subscription_renewUrgent.tr(
                        args: [
                          LocaleKeys.subscription_daysLeft.plural(
                            status.daysLeft ?? 0,
                          ),
                        ],
                      )
                    : LocaleKeys.subscription_renewSoon.tr(
                        args: [formatDate(status.endsAt!)],
                      ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Routemaster.of(context).push('/tariffs'),
              child: Text(LocaleKeys.subscription_renew.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemindersSwitch extends StatelessWidget {
  const _RemindersSwitch({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: status.remindersEnabled,
      title: Text(LocaleKeys.subscription_remindersTitle.tr()),
      subtitle: Text(LocaleKeys.subscription_remindersSubtitle.tr()),
      onChanged: (value) =>
          context.read<SubscriptionBloc>().add(RemindersToggled(value)),
    );
  }
}

class _PeriodsCard extends StatelessWidget {
  const _PeriodsCard({required this.periods});

  final List<SubscriptionPeriod> periods;

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
              LocaleKeys.subscription_periodsTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final period in periods)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${LocaleKeys.subscription_periodRow.tr(namedArgs: {'from': formatDate(period.startsAt), 'to': formatDate(period.endsAt)})}'
                  ' · ${tariffKindName(period.kind ?? TariffKind.basic)}'
                  '${period.revoked ? ' · ${LocaleKeys.subscription_revoked.tr()}' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.orders});

  final List<Order> orders;

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
              LocaleKeys.subscription_ordersTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${formatDate(order.createdAt)} · '
                  '${tariffKindName(order.kind)}, ${monthsLabel(order.months)} · '
                  '${priceLabel(order.amountRsd)} · '
                  '${orderStatusLabel(order.status)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}
