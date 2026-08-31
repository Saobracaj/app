import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../../subscription/models/subscription_models.dart';
import '../../subscription/presentation/tariff_formatting.dart';
import '../state_management/billing_admin_bloc.dart';
import '../state_management/billing_admin_events.dart';
import '../state_management/billing_admin_state.dart';
import 'reason_dialog.dart';

/// Денежный стол (настройки › «Платежи и подписки») — админка платежей:
/// покупки в сторах, карточка пользователя с ручными выдачами, журнал и
/// каталог тарифов. Виден держателям `manage_billing`; право проверяет бэкенд
/// на каждом запросе.
///
/// Подтверждать оплату здесь нечего: деньги берут App Store и Google Play,
/// право появляется по проверенному чеку. Оператору остались наблюдение и
/// ручные операции — возврат, компенсация, апгрейд тарифа.
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
/// правую панель настроек (там ему нужна ограниченная высота: список покупок
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
            Expanded(
              child: switch (state.tab) {
                BillingTab.purchases => _PurchasesTab(state: state),
                BillingTab.user => _UserTab(state: state),
                BillingTab.audit => _AuditTab(state: state),
                BillingTab.tariffs => _TariffsTab(state: state),
              },
            ),
          ],
        );
      },
    );
  }
}

/// Вкладки — чипы в горизонтальной прокрутке: выбор живёт в блоке, поэтому
/// контроллер TabBar не нужен, а на телефоне четыре вкладки не тесно.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected});

  final BillingTab selected;

  static String _label(BillingTab tab) => switch (tab) {
    BillingTab.purchases => LocaleKeys.billingAdmin_tabPurchases.tr(),
    BillingTab.user => LocaleKeys.billingAdmin_tabUser.tr(),
    BillingTab.audit => LocaleKeys.billingAdmin_tabAudit.tr(),
    BillingTab.tariffs => LocaleKeys.billingAdmin_tabTariffs.tr(),
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

// =========================================================================
// Покупки
// =========================================================================

class _PurchasesTab extends StatelessWidget {
  const _PurchasesTab({required this.state});

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
              DropdownMenu<StorePlatform?>(
                initialSelection: state.platformFilter,
                width: 190,
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                    value: null,
                    label: LocaleKeys.billingAdmin_platformAll.tr(),
                  ),
                  for (final p in StorePlatform.values)
                    DropdownMenuEntry(value: p, label: storePlatformName(p)),
                ],
                onSelected: (value) => bloc.add(
                  PurchasesFilterChanged(
                    platform: value,
                    clearPlatform: value == null,
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
                      onPressed: () => bloc.add(PurchasesFilterChanged()),
                    ),
                  ),
                  onChanged: (v) => bloc.add(SearchDraftChanged(v)),
                  onFieldSubmitted: (_) => bloc.add(PurchasesFilterChanged()),
                ),
              ),
              IconButton(
                tooltip: LocaleKeys.billingAdmin_refresh.tr(),
                icon: const Icon(Icons.refresh),
                onPressed: () => bloc.add(PurchasesRefreshed()),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.purchasesLoading
              ? const Center(child: CircularProgressIndicator())
              : state.purchases.isEmpty
              ? Center(child: Text(LocaleKeys.billingAdmin_noPurchases.tr()))
              : ListView.separated(
                  itemCount: state.purchases.length,
                  separatorBuilder: (_, _) => const Divider(height: 0),
                  itemBuilder: (context, index) =>
                      _PurchaseTile(purchase: state.purchases[index]),
                ),
        ),
        if (state.purchasesTotal > state.purchasesPageSize)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: state.hasPrevPage
                      ? () => bloc.add(
                          PurchasesPageRequested(
                            state.purchasesOffset - state.purchasesPageSize,
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
                        'from': '${state.purchasesOffset + 1}',
                        'to':
                            '${state.purchasesOffset + state.purchases.length}',
                        'total': '${state.purchasesTotal}',
                      },
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: state.hasNextPage
                      ? () => bloc.add(
                          PurchasesPageRequested(
                            state.purchasesOffset + state.purchasesPageSize,
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

/// Строка покупки: кто, что, где куплено и что с ней сейчас. Идентификатор
/// платежа виден целиком — по нему покупку ищут в консоли стора, когда человек
/// приходит с вопросом о возврате.
class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase});

  final StorePurchase purchase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListTile(
      title: Text(
        '${tariffKindName(purchase.kind)}, ${monthsLabel(purchase.months)}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(purchase.userEmail ?? '—', style: muted),
          Text(
            '${storePlatformName(purchase.platform)} · '
            '${formatDateTime(purchase.purchasedAt)}'
            '${purchase.autoRenewing ? ' · ${LocaleKeys.subscription_autoRenewOn.tr()}' : ''}',
            style: muted,
          ),
          SelectableText(purchase.transactionId, style: muted),
        ],
      ),
      isThreeLine: true,
      trailing: _PurchaseStatusChip(status: purchase.status),
    );
  }
}

class _PurchaseStatusChip extends StatelessWidget {
  const _PurchaseStatusChip({required this.status});

  final StorePurchaseStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      StorePurchaseStatus.active => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      StorePurchaseStatus.expired => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      StorePurchaseStatus.refunded => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        purchaseStatusLabel(status),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
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
          _UserPurchasesCard(purchases: user.purchases),
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
                    '${p.fromPurchase ? LocaleKeys.billingAdmin_periodSourcePurchase.tr() : LocaleKeys.billingAdmin_periodSourceManual.tr()}'
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
class _UserPurchasesCard extends StatelessWidget {
  const _UserPurchasesCard({required this.purchases});

  final List<StorePurchase> purchases;

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
              LocaleKeys.billingAdmin_purchasesHistoryTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (purchases.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(LocaleKeys.billingAdmin_noUserPurchases.tr()),
            )
          else
            for (final p in purchases) _PurchaseTile(purchase: p),
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
                      // Идентификаторы товаров — то, по чему приложение
                      // спрашивает у стора цену: расхождение с консолью
                      // выглядит как «кнопка купить ничего не делает».
                      Text(
                        '${LocaleKeys.subscription_platformApple.tr()}: '
                        '${t.appleProductId.isEmpty ? '—' : t.appleProductId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${LocaleKeys.subscription_platformGoogle.tr()}: '
                        '${t.googleProductId.isEmpty ? '—' : t.googleProductId}'
                        '${t.autoRenewing ? ' · ${LocaleKeys.subscription_autoRenewOn.tr()}' : ''}',
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
