import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di.dart';
import '../../core/responsive.dart';
import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';
import 'tariff_formatting.dart';

/// Раздел аккаунта «Подписка»: текущий тариф, срок действия, покупки и
/// история периодов.
///
/// Экран есть везде, включая веб: подписка — состояние аккаунта, а не только
/// приложения. Купить её можно лишь в приложении (через стор), и оттуда же ей
/// управляют — отменить автопродление умеет только сам стор.
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
                // Напоминания об окончании незачем тому, кому стор продлит
                // подписку сам, — письма про это и не приходят.
                if (state.subscription.active &&
                    !state.subscription.autoRenewing) ...[
                  const SizedBox(height: 12),
                  _RemindersSwitch(status: state.subscription),
                ],
                if (state.periods.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _PeriodsCard(periods: state.periods),
                ],
                if (state.purchases.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PurchasesCard(purchases: state.purchases),
                ],
                const SizedBox(height: 12),
                _RestoreCard(state: state),
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
    final manageUrl = status.manageUrl;
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
              // Дата у автоподписки — день следующего списания, а не день, в
              // который доступ закончится. Путать эти два — прямой путь к
              // «я думал, оно само отключится».
              Text(
                status.autoRenewing
                    ? LocaleKeys.subscription_renewsOn.tr(
                        args: [formatDate(status.endsAt!)],
                      )
                    : LocaleKeys.subscription_activeUntil.tr(
                        args: [formatDate(status.endsAt!)],
                      ),
                style: theme.textTheme.bodyMedium,
              ),
            if (status.daysLeft != null && !status.autoRenewing)
              Text(
                LocaleKeys.subscription_daysLeft.plural(status.daysLeft!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (status.autoRenewing) ...[
              const SizedBox(height: 8),
              Text(
                LocaleKeys.subscription_manageInStoreHint.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (manageUrl != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(manageUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(LocaleKeys.subscription_manageInStore.tr()),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Плашка «пора продлить» за 14 и за 3 дня до конца — только у подписки,
/// которую никто не продлит автоматически.
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

/// «Восстановить покупки». В вебе стора нет — там карточка объясняет, что
/// подписка оформляется в приложении, и никуда не ведёт.
class _RestoreCard extends StatelessWidget {
  const _RestoreCard({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storeAvailable =
        context.read<SubscriptionBloc>().storePlatform != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              storeAvailable
                  ? LocaleKeys.subscription_restoreHint.tr()
                  : LocaleKeys.subscription_webOnlyBody.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (storeAvailable)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: state.busy
                      ? null
                      : () => context.read<SubscriptionBloc>().add(
                          PurchasesRestoreRequested(),
                        ),
                  child: Text(LocaleKeys.subscription_restore.tr()),
                ),
              ),
          ],
        ),
      ),
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
                  '${period.autoRenewing ? ' · ${LocaleKeys.subscription_autoRenewOn.tr()}' : ''}'
                  '${period.fromPurchase ? '' : ' · ${LocaleKeys.subscription_periodSourceManual.tr()}'}'
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

/// Покупки в сторе — история и одновременно то, что человек назовёт в
/// поддержке: идентификатор платежа виден здесь.
class _PurchasesCard extends StatelessWidget {
  const _PurchasesCard({required this.purchases});

  final List<StorePurchase> purchases;

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
              LocaleKeys.subscription_purchasesTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final purchase in purchases)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatDate(purchase.purchasedAt)} · '
                      '${tariffKindName(purchase.kind)}, ${monthsLabel(purchase.months)} · '
                      '${storePlatformName(purchase.platform)} · '
                      '${purchaseStatusLabel(purchase.status)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (purchase.transactionId.isNotEmpty)
                      Text(
                        purchase.transactionId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
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
