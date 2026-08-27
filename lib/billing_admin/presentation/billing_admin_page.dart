import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/presentation/payment_slip_view.dart';
import '../../subscription/presentation/tariff_formatting.dart';
import '../models/billing_admin_models.dart';
import '../state_management/billing_admin_bloc.dart';
import '../state_management/billing_admin_events.dart';
import '../state_management/billing_admin_state.dart';
import 'reason_dialog.dart';

/// Денежный стол (настройки › «Платежи и подписки») — админка платежей,
/// перенесённая из Angular-панели в приложение: заказы с подтверждением
/// оплаты, карточка пользователя с ручными выдачами, журнал, тарифы и
/// реквизиты получателя. Виден держателям `manage_billing`; право проверяет
/// бэкенд на каждом запросе.
class BillingAdminPage extends StatelessWidget {
  const BillingAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.billingAdmin_title.tr())),
      body: const SafeArea(child: BillingAdminContent()),
    );
  }
}

/// Содержимое стола без Scaffold — встраивается и в отдельный экран, и в
/// правую панель настроек (там ему нужна ограниченная высота: список заказов
/// со своей прокруткой).
class BillingAdminContent extends StatelessWidget {
  const BillingAdminContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BillingAdminBloc>()..add(BillingAdminStarted()),
      child: const _BillingView(),
    );
  }
}

class _BillingView extends StatelessWidget {
  const _BillingView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BillingAdminBloc, BillingAdminState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null &&
              curr.errorMessage != prev.errorMessage) ||
          (curr.infoMessage != null && curr.infoMessage != prev.infoMessage),
      listener: (context, state) {
        final message = state.errorMessage ?? state.infoMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TabStrip(selected: state.tab),
            if (state.payeeMissing && state.tab != BillingTab.payee)
              _PayeeMissingBanner(),
            Expanded(
              child: switch (state.tab) {
                BillingTab.orders => _OrdersTab(state: state),
                BillingTab.user => _UserTab(state: state),
                BillingTab.audit => _AuditTab(state: state),
                BillingTab.tariffs => _TariffsTab(state: state),
                BillingTab.promos => _PromosTab(state: state),
                BillingTab.payee => _PayeeTab(state: state),
              },
            ),
          ],
        );
      },
    );
  }
}

/// Вкладки — чипы в горизонтальной прокрутке: выбор живёт в блоке, поэтому
/// контроллер TabBar не нужен, а на телефоне пять вкладок не тесно.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected});

  final BillingTab selected;

  static String _label(BillingTab tab) => switch (tab) {
    BillingTab.orders => LocaleKeys.billingAdmin_tabOrders.tr(),
    BillingTab.user => LocaleKeys.billingAdmin_tabUser.tr(),
    BillingTab.audit => LocaleKeys.billingAdmin_tabAudit.tr(),
    BillingTab.tariffs => LocaleKeys.billingAdmin_tabTariffs.tr(),
    BillingTab.promos => LocaleKeys.billingAdmin_tabPromos.tr(),
    BillingTab.payee => LocaleKeys.billingAdmin_tabPayee.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillingAdminBloc>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final tab in BillingTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_label(tab)),
                selected: tab == selected,
                onSelected: (_) => bloc.add(BillingTabSelected(tab)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PayeeMissingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MaterialBanner(
      backgroundColor: theme.colorScheme.errorContainer,
      content: Text(
        LocaleKeys.billingAdmin_payeeMissingBanner.tr(),
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      leading: Icon(Icons.warning_amber, color: theme.colorScheme.error),
      actions: [
        TextButton(
          onPressed: () => context.read<BillingAdminBloc>().add(
            BillingTabSelected(BillingTab.payee),
          ),
          child: Text(LocaleKeys.billingAdmin_tabPayee.tr()),
        ),
      ],
    );
  }
}

// =========================================================================
// Заказы
// =========================================================================

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillingAdminBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownMenu<OrderStatus?>(
                initialSelection: state.statusFilter,
                width: 190,
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                    value: null,
                    label: LocaleKeys.billingAdmin_statusAll.tr(),
                  ),
                  for (final s in OrderStatus.values)
                    DropdownMenuEntry(value: s, label: orderStatusLabel(s)),
                ],
                onSelected: (value) => bloc.add(
                  OrdersFilterChanged(
                    status: value,
                    clearStatus: value == null,
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  initialValue: state.searchDraft,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.billingAdmin_searchHint.tr(),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => bloc.add(OrdersFilterChanged()),
                    ),
                  ),
                  onChanged: (v) => bloc.add(SearchDraftChanged(v)),
                  onFieldSubmitted: (_) => bloc.add(OrdersFilterChanged()),
                ),
              ),
              IconButton(
                tooltip: LocaleKeys.billingAdmin_refresh.tr(),
                icon: const Icon(Icons.refresh),
                onPressed: () => bloc.add(OrdersRefreshed()),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.ordersLoading
              ? const Center(child: CircularProgressIndicator())
              : state.orders.isEmpty
              ? Center(child: Text(LocaleKeys.billingAdmin_noOrders.tr()))
              : ListView.separated(
                  itemCount: state.orders.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (context, index) => _OrderTile(
                    order: state.orders[index],
                    submitting: state.submitting,
                  ),
                ),
        ),
        if (state.ordersTotal > state.ordersPageSize)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: state.hasPrevPage
                      ? () => bloc.add(
                          OrdersPageRequested(
                            state.ordersOffset - state.ordersPageSize,
                          ),
                        )
                      : null,
                  child: Text(LocaleKeys.billingAdmin_prev.tr()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    LocaleKeys.billingAdmin_pagerRange.tr(
                      namedArgs: {
                        'from': '${state.ordersOffset + 1}',
                        'to': '${state.ordersOffset + state.orders.length}',
                        'total': '${state.ordersTotal}',
                      },
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: state.hasNextPage
                      ? () => bloc.add(
                          OrdersPageRequested(
                            state.ordersOffset + state.ordersPageSize,
                          ),
                        )
                      : null,
                  child: Text(LocaleKeys.billingAdmin_next.tr()),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Строка заказа: кто, что, сколько, позив на број, статус; у ожидающего —
/// кнопки «Оплачен»/«Отменить» и уплатница по раскрытию.
class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.submitting});

  final Order order;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final title = Row(
      children: [
        Expanded(
          child: Text(
            order.userEmail ?? order.userId ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _StatusChip(order: order),
      ],
    );
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(
          '${tariffKindName(order.kind)}, ${monthsLabel(order.months)} · '
          '${priceLabel(order.amountRsd)}'
          '${order.promoCode == null ? '' : ' · ${LocaleKeys.billingAdmin_promoLabel.tr(namedArgs: {
                'code': order.promoCode!,
                'percent': '${order.discountPercent ?? 0}',
              })}'}',
        ),
        Text(
          '${LocaleKeys.subscription_reference.tr()}: ${order.referenceDisplay}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '${LocaleKeys.billingAdmin_created.tr()} ${formatDateTime(order.createdAt)}'
          '${order.isPending ? ' · ${LocaleKeys.billingAdmin_dueUntil.tr(args: [formatDate(order.paymentDueAt)])}' : ''}',
          style: muted,
        ),
      ],
    );
    if (!order.isPending) {
      return ListTile(title: title, subtitle: subtitle, isThreeLine: true);
    }
    return ExpansionTile(
      title: title,
      subtitle: subtitle,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton(
              onPressed: submitting ? null : () => confirmOrder(context, order),
              child: Text(LocaleKeys.billingAdmin_confirmPaid.tr()),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: submitting ? null : () => cancelOrder(context, order),
              child: Text(LocaleKeys.billingAdmin_cancelOrder.tr()),
            ),
          ],
        ),
        if (order.payment != null) ...[
          const SizedBox(height: 12),
          PaymentSlipView(slip: order.payment!, compact: true),
        ],
      ],
    );
  }

  static Future<void> confirmOrder(BuildContext context, Order order) async {
    final bloc = context.read<BillingAdminBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.billingAdmin_confirmTitle.tr()),
        content: Text(
          LocaleKeys.billingAdmin_confirmBody.tr(
            namedArgs: {
              'reference': order.referenceDisplay,
              'amount': amountLabel(order.amountRsd),
              'email': order.userEmail ?? '',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocaleKeys.comments_cancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocaleKeys.billingAdmin_confirmPaid.tr()),
          ),
        ],
      ),
    );
    if (ok == true) bloc.add(OrderConfirmed(order.id));
  }

  static Future<void> cancelOrder(BuildContext context, Order order) async {
    final bloc = context.read<BillingAdminBloc>();
    final result = await showReasonDialog(
      context,
      title: LocaleKeys.billingAdmin_cancelTitle.tr(),
      body: LocaleKeys.billingAdmin_cancelBody.tr(
        namedArgs: {
          'reference': order.referenceDisplay,
          'email': order.userEmail ?? '',
        },
      ),
      hint: LocaleKeys.billingAdmin_reasonHint.tr(),
      action: LocaleKeys.billingAdmin_cancelOrder.tr(),
      destructive: true,
    );
    if (result != null) {
      bloc.add(OrderCancelledByAdmin(order.id, reason: result.reason));
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (order.status) {
      OrderStatus.pending => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      OrderStatus.paid => (scheme.primaryContainer, scheme.onPrimaryContainer),
      OrderStatus.cancelled || OrderStatus.expired => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        orderStatusLabel(order.status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

// =========================================================================
// Пользователь
// =========================================================================

class _UserTab extends StatelessWidget {
  const _UserTab({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillingAdminBloc>();
    final theme = Theme.of(context);
    final user = state.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: state.userEmailDraft,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: LocaleKeys.billingAdmin_userEmailHint.tr(),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(UserEmailDraftChanged(v)),
                onFieldSubmitted: (v) => bloc.add(UserLookedUp(v)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: state.userLoading
                  ? null
                  : () => bloc.add(UserLookedUp(state.userEmailDraft)),
              child: Text(LocaleKeys.billingAdmin_openCard.tr()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.userLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (state.userNotFound)
          Text(LocaleKeys.billingAdmin_userNotFound.tr())
        else if (user != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    user.subscription.active
                        ? LocaleKeys.billingAdmin_subscriptionActive.tr(
                            namedArgs: {
                              'kind': user.subscription.kind == null
                                  ? '—'
                                  : tariffKindName(user.subscription.kind!),
                              'date': user.subscription.endsAt == null
                                  ? '—'
                                  : formatDate(user.subscription.endsAt!),
                              'days': '${user.subscription.daysLeft ?? 0}',
                            },
                          )
                        : LocaleKeys.billingAdmin_noActiveSubscription.tr(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocaleKeys.billingAdmin_featureKeys.tr(
                      args: [
                        user.subscription.featureKeys.isEmpty
                            ? '—'
                            : user.subscription.featureKeys.join(', '),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GrantCard(state: state),
          const SizedBox(height: 12),
          _PeriodsCard(periods: user.periods),
          const SizedBox(height: 12),
          _UserOrdersCard(orders: user.orders, submitting: state.submitting),
        ],
      ],
    );
  }
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BillingAdminBloc>();
    final theme = Theme.of(context);
    final months = state.grantMonthsValue;
    final canAct = !state.submitting && months != null;
    final note = state.grantNote.trim().isEmpty ? null : state.grantNote.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.billingAdmin_manualTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownMenu<TariffKind>(
                  initialSelection: state.grantKind,
                  width: 230,
                  label: Text(LocaleKeys.billingAdmin_kindField.tr()),
                  dropdownMenuEntries: [
                    for (final k in TariffKind.values)
                      DropdownMenuEntry(value: k, label: tariffKindName(k)),
                  ],
                  onSelected: (k) => bloc.add(GrantFormChanged(kind: k)),
                ),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: state.grantMonths,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.billingAdmin_monthsField.tr(),
                      errorText: state.grantMonths.isNotEmpty && months == null
                          ? LocaleKeys.billingAdmin_monthsInvalid.tr()
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => bloc.add(GrantFormChanged(months: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: state.grantNote,
              decoration: InputDecoration(
                labelText: LocaleKeys.billingAdmin_noteHint.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => bloc.add(GrantFormChanged(note: v)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: canAct
                      ? () => bloc.add(
                          SubscriptionGranted(
                            kind: state.grantKind,
                            months: months,
                            note: note,
                          ),
                        )
                      : null,
                  child: Text(LocaleKeys.billingAdmin_grant.tr()),
                ),
                OutlinedButton(
                  onPressed: canAct
                      ? () => bloc.add(
                          SubscriptionExtended(months: months, note: note),
                        )
                      : null,
                  child: Text(LocaleKeys.billingAdmin_extend.tr()),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: state.submitting ? null : () => _revoke(context),
                  child: Text(LocaleKeys.billingAdmin_revoke.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.billingAdmin_manualHint.tr(),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revoke(BuildContext context) async {
    final bloc = context.read<BillingAdminBloc>();
    final email = state.user?.email ?? '';
    final result = await showReasonDialog(
      context,
      title: LocaleKeys.billingAdmin_revokeTitle.tr(),
      body: LocaleKeys.billingAdmin_revokeBody.tr(namedArgs: {'email': email}),
      hint: LocaleKeys.billingAdmin_noteHint.tr(),
      action: LocaleKeys.billingAdmin_revoke.tr(),
      destructive: true,
      initialReason: state.grantNote,
    );
    if (result != null) bloc.add(SubscriptionRevoked(note: result.reason));
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
              LocaleKeys.billingAdmin_periodsTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (periods.isEmpty)
              Text(LocaleKeys.billingAdmin_noPeriods.tr())
            else
              for (final p in periods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${formatDate(p.startsAt)} — ${formatDate(p.endsAt)} · '
                    '${p.kind == null ? '—' : tariffKindName(p.kind!)} · '
                    '${p.fromOrder ? LocaleKeys.billingAdmin_periodSourceOrder.tr() : LocaleKeys.billingAdmin_periodSourceManual.tr()}'
                    '${p.revoked ? ' · ${LocaleKeys.billingAdmin_revokedLabel.tr()}' : ''}'
                    '${p.note == null || p.note!.isEmpty ? '' : ' · ${p.note}'}',
                    style: p.revoked
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _UserOrdersCard extends StatelessWidget {
  const _UserOrdersCard({required this.orders, required this.submitting});

  final List<Order> orders;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              LocaleKeys.billingAdmin_ordersHistoryTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(LocaleKeys.billingAdmin_noUserOrders.tr()),
            )
          else
            for (final o in orders)
              _OrderTile(order: o, submitting: submitting),
        ],
      ),
    );
  }
}

// =========================================================================
// Журнал
// =========================================================================

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BillingAdminBloc>();
    if (state.auditLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.billingAdmin_auditHint.tr(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: LocaleKeys.billingAdmin_refresh.tr(),
                icon: const Icon(Icons.refresh),
                onPressed: () => bloc.add(AuditRefreshed()),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.audit.isEmpty
              ? Center(child: Text(LocaleKeys.billingAdmin_auditEmpty.tr()))
              : ListView.separated(
                  itemCount: state.audit.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final a = state.audit[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${a.action} · ${a.actorEmail ?? LocaleKeys.billingAdmin_system.tr()}',
                      ),
                      subtitle: Text(
                        '${formatDateTime(a.createdAt)}'
                        '${a.details == null || a.details!.isEmpty ? '' : '\n${a.details}'}',
                      ),
                      isThreeLine: a.details != null && a.details!.isNotEmpty,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =========================================================================
// Тарифы
// =========================================================================

class _TariffsTab extends StatelessWidget {
  const _TariffsTab({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BillingAdminBloc>();
    if (state.tariffsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Text(
          LocaleKeys.billingAdmin_tariffsHint.tr(),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final t in state.tariffs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tariffKindName(t.kind)}, ${monthsLabel(t.months)}',
                      ),
                      Text(
                        t.sku,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Focus(
                    onFocusChange: (has) {
                      if (!has) bloc.add(TariffPriceCommitted(t.sku));
                    },
                    child: TextFormField(
                      // Ключ по цене с сервера: после сохранения поле
                      // пересоздаётся с новым значением.
                      key: ValueKey('price:${t.sku}:${t.priceRsd}'),
                      initialValue: state.priceDrafts[t.sku] ?? '${t.priceRsd}',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.billingAdmin_priceRsd.tr(),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          bloc.add(TariffPriceDraftChanged(t.sku, v)),
                      onFieldSubmitted: (_) =>
                          bloc.add(TariffPriceCommitted(t.sku)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: LocaleKeys.billingAdmin_inShop.tr(),
                  child: Switch(
                    value: t.active,
                    onChanged: state.submitting
                        ? null
                        : (v) => bloc.add(TariffActiveToggled(t.sku, v)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =========================================================================
// Промокоды
// =========================================================================

class _PromosTab extends StatelessWidget {
  const _PromosTab({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BillingAdminBloc>();
    if (state.promosLoading && !state.promosLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                LocaleKeys.billingAdmin_promosHint.tr(),
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: LocaleKeys.billingAdmin_refresh.tr(),
              icon: const Icon(Icons.refresh),
              onPressed: () => bloc.add(PromosRefreshed()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PromoGenerateCard(state: state),
        if (state.generatedPromoCodes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GeneratedPromosCard(codes: state.generatedPromoCodes),
        ],
        const SizedBox(height: 12),
        if (state.promoCodes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(LocaleKeys.billingAdmin_noPromos.tr()),
          )
        else
          for (final promo in state.promoCodes)
            _PromoTile(promo: promo, submitting: state.submitting),
      ],
    );
  }
}

/// Форма генерации: количество, скидка, срок, привязка к тарифу, комментарий.
class _PromoGenerateCard extends StatelessWidget {
  const _PromoGenerateCard({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BillingAdminBloc>();
    final validUntil = state.promoValidUntil;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.billingAdmin_promoGenerateTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    initialValue: state.promoCount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.billingAdmin_promoCountField.tr(),
                      errorText:
                          state.promoCount.trim().isNotEmpty &&
                              state.promoCountValue == null
                          ? LocaleKeys.billingAdmin_promoCountInvalid.tr()
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => bloc.add(PromoFormChanged(count: v)),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    initialValue: state.promoDiscount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.billingAdmin_promoDiscountField
                          .tr(),
                      errorText:
                          state.promoDiscount.trim().isNotEmpty &&
                              state.promoDiscountValue == null
                          ? LocaleKeys.billingAdmin_promoDiscountInvalid.tr()
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => bloc.add(PromoFormChanged(discount: v)),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                    validUntil == null
                        ? LocaleKeys.billingAdmin_promoValidUntilField.tr()
                        : LocaleKeys.billingAdmin_dueUntil.tr(
                            args: [formatDate(validUntil)],
                          ),
                  ),
                  onPressed: () => _pickDate(context),
                ),
                DropdownMenu<String?>(
                  initialSelection: state.promoSku,
                  width: 260,
                  label: Text(LocaleKeys.billingAdmin_promoTariffField.tr()),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: null,
                      label: LocaleKeys.billingAdmin_promoTariffAny.tr(),
                    ),
                    for (final t in state.tariffs)
                      DropdownMenuEntry(
                        value: t.sku,
                        label:
                            '${tariffKindName(t.kind)}, ${monthsLabel(t.months)}',
                      ),
                  ],
                  onSelected: (sku) => bloc.add(
                    PromoFormChanged(sku: sku, clearSku: sku == null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: state.promoNote,
              decoration: InputDecoration(
                labelText: LocaleKeys.billingAdmin_noteHint.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => bloc.add(PromoFormChanged(note: v)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.canGeneratePromos && !state.submitting
                  ? () => bloc.add(PromoCodesGenerated())
                  : null,
              icon: state.submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(LocaleKeys.billingAdmin_generateCodes.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final bloc = context.read<BillingAdminBloc>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.promoValidUntil ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) bloc.add(PromoFormChanged(validUntil: picked));
  }
}

/// Только что сгенерированные коды — одним блоком, чтобы скопировать и
/// отправить. После ухода со стола пачка не восстанавливается, но коды всегда
/// видны в общем списке ниже.
class _GeneratedPromosCard extends StatelessWidget {
  const _GeneratedPromosCard({required this.codes});

  final List<AdminPromoCode> codes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = codes.map((c) => c.code).join('\n');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocaleKeys.billingAdmin_generatedTitle.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(LocaleKeys.billingAdmin_promoCopyAll.tr()),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            LocaleKeys.billingAdmin_promoCopied.tr(),
                          ),
                        ),
                      );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({required this.promo, required this.submitting});

  final AdminPromoCode promo;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BillingAdminBloc>();
    final scheme = theme.colorScheme;
    final (bg, fg) = switch (promo.status) {
      PromoCodeStatus.available => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      PromoCodeStatus.locked => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      PromoCodeStatus.used || PromoCodeStatus.expired => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    final details = [
      '−${promo.discountPercent}%',
      LocaleKeys.billingAdmin_dueUntil.tr(args: [formatDate(promo.validUntil)]),
      promo.sku ?? LocaleKeys.billingAdmin_promoTariffAny.tr(),
      if (promo.usedByEmail != null) promo.usedByEmail!,
      if (promo.note != null && promo.note!.isNotEmpty) promo.note!,
    ].join(' · ');
    // Удалять можно только код, не занятый заказом, — сервер откажет
    // остальным; кнопку им не показываем.
    final deletable =
        promo.status == PromoCodeStatus.available ||
        promo.status == PromoCodeStatus.expired;
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Text(
            promo.code,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(promo.status),
              style: theme.textTheme.labelSmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
      subtitle: Text(details),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: LocaleKeys.subscription_copyValue.tr(),
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: promo.code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(LocaleKeys.billingAdmin_promoCopied.tr()),
                  ),
                );
            },
          ),
          if (deletable)
            IconButton(
              tooltip: LocaleKeys.billingAdmin_promoDelete.tr(),
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: submitting
                  ? null
                  : () => bloc.add(PromoCodeDeleted(promo.code)),
            ),
        ],
      ),
    );
  }

  static String _statusLabel(PromoCodeStatus status) => switch (status) {
    PromoCodeStatus.available => LocaleKeys.billingAdmin_promoStatusAvailable
        .tr(),
    PromoCodeStatus.locked => LocaleKeys.billingAdmin_promoStatusLocked.tr(),
    PromoCodeStatus.used => LocaleKeys.billingAdmin_promoStatusUsed.tr(),
    PromoCodeStatus.expired => LocaleKeys.billingAdmin_promoStatusExpired.tr(),
  };
}

// =========================================================================
// Реквизиты получателя
// =========================================================================

class _PayeeTab extends StatelessWidget {
  const _PayeeTab({required this.state});

  final BillingAdminState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BillingAdminBloc>();
    if (state.payeeLoading && state.payee == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final draft = state.payeeDraft;
    final payee = state.payee;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          LocaleKeys.billingAdmin_payeeTitle.tr(),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          LocaleKeys.billingAdmin_payeeHint.tr(),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (payee != null && payee.configured)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(LocaleKeys.billingAdmin_payeeConfigured.tr()),
                ),
              ],
            ),
          ),
        TextFormField(
          // Ключ по сохранённому счёту: после сохранения сервер возвращает
          // нормализованную форму, и поле должно её показать.
          key: ValueKey('account:${payee?.accountNumber}'),
          initialValue: draft.accountNumber,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: LocaleKeys.billingAdmin_accountField.tr(),
            helperText: LocaleKeys.billingAdmin_accountHint.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => bloc.add(PayeeDraftChanged(accountNumber: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.name,
          decoration: InputDecoration(
            labelText: LocaleKeys.billingAdmin_nameField.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => bloc.add(PayeeDraftChanged(name: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.address,
          decoration: InputDecoration(
            labelText: LocaleKeys.billingAdmin_addressField.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => bloc.add(PayeeDraftChanged(address: v)),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: TextFormField(
                initialValue: draft.paymentCode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LocaleKeys.billingAdmin_paymentCodeField.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(PayeeDraftChanged(paymentCode: v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.purpose,
                decoration: InputDecoration(
                  labelText: LocaleKeys.billingAdmin_purposeField.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => bloc.add(PayeeDraftChanged(purpose: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: draft.canSave && !state.submitting
                ? () => bloc.add(PayeeSaved())
                : null,
            icon: state.submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(LocaleKeys.billingAdmin_save.tr()),
          ),
        ),
      ],
    );
  }
}
