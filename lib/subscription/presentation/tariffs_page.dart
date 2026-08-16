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
import 'plan_features.dart';
import 'tariff_formatting.dart';

/// Витрина тарифов: три срока в один ряд, русские материалы — надбавкой.
///
/// Сроки стоят рядом намеренно. Месячный тариф — это точка отсчёта: его цена за
/// месяц втрое выше годовой, и увидеть это можно, только когда обе цифры на
/// экране одновременно и в одной единице. Поэтому крупная цифра в каждой
/// карточке — цена за месяц, а полная сумма подписана мелко.
///
/// Русский не отдельный план, а тумблер: семейств тарифов на бэкенде
/// по-прежнему два (`basic_*` / `russian_*`), но человек выбирает срок один
/// раз, а не из шести комбинаций.
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
            // Список во всю ширину, поля — в его padding: полоса прокрутки
            // тогда идёт по краю окна, а не посреди экрана, и колесо мыши
            // работает над любой точкой страницы, а не только над колонкой.
            return ListView(
              padding: readableInsets(
                context,
                maxWidth: 900,
                top: 16,
                bottom: 32,
              ),
              children: [
                // Уже созданный заказ — сверху: человек вернулся доплатить,
                // а не выбрать второй тариф.
                if (state.pendingOrder != null) ...[
                  PendingOrderCard(order: state.pendingOrder!),
                  const SizedBox(height: 16),
                ],
                const _OneTimeNote(),
                const SizedBox(height: 16),
                _TermRow(state: state),
                const SizedBox(height: 12),
                _RussianAddon(state: state),
                const SizedBox(height: 28),
                const PlanFeaturesComparison(),
                const SizedBox(height: 16),
                const _FreeTierCard(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Главный страх разовой оплаты переводом — «а не спишут ли потом ещё раз».
/// Автопродления в системе нет вообще, и сказать об этом стоит до цен.
class _OneTimeNote extends StatelessWidget {
  const _OneTimeNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              LocaleKeys.subscription_oneTimeNote.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Три срока рядом. На узком экране — стопкой, самый выгодный первым: на
/// телефоне порядок и есть рекомендация.
class _TermRow extends StatelessWidget {
  const _TermRow({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final tariffs = state.offeredTariffs;
    if (tariffs.isEmpty) return const SizedBox.shrink();
    final longest = tariffs.last;

    final cards = [
      for (final tariff in tariffs)
        _TermCard(
          tariff: tariff,
          state: state,
          recommended: tariff.sku == longest.sku,
        ),
    ];

    if (!context.isMediumScreen) {
      // Стопкой — от самого длинного срока к самому короткому: на телефоне
      // порядок и есть рекомендация.
      final stacked = cards.reversed.toList();
      return Column(
        children: [
          for (var i = 0; i < stacked.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            stacked[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({
    required this.tariff,
    required this.state,
    required this.recommended,
  });

  final Tariff tariff;
  final SubscriptionState state;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authenticated = context.select(
      (AuthBloc bloc) => bloc.state.isAuthenticated,
    );
    final saving = state.savingPercent(tariff);
    final savedRsd = state.savingRsd(tariff);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: recommended
            ? Color.alphaBlend(
                theme.colorScheme.primaryContainer.withValues(alpha: .38),
                theme.colorScheme.surface,
              )
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recommended
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: recommended ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthsLabel(tariff.months),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (saving != null)
                _SaveBadge(percent: saving, filled: recommended),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pricePerMonthLabel(tariff),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            LocaleKeys.subscription_perMonthUnit.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Text(
            payTotalLabel(tariff.priceRsd),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            // У месячного «экономии» нет — вместо неё честное предупреждение,
            // что продлевать придётся руками. Это и есть довод в пользу года.
            savedRsd == null
                ? LocaleKeys.subscription_monthlyRenewNote.tr()
                : LocaleKeys.subscription_savingNote.tr(
                    args: [amountLabel(savedRsd)],
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (authenticated)
            recommended
                ? FilledButton(
                    onPressed: state.submitting
                        ? null
                        : () => context.read<SubscriptionBloc>().add(
                            OrderRequested(tariff.sku),
                          ),
                    child: Text(LocaleKeys.subscription_choose.tr()),
                  )
                : OutlinedButton(
                    onPressed: state.submitting
                        ? null
                        : () => context.read<SubscriptionBloc>().add(
                            OrderRequested(tariff.sku),
                          ),
                    child: Text(LocaleKeys.subscription_choose.tr()),
                  )
          else
            OutlinedButton(
              onPressed: () => Routemaster.of(context).push('/login'),
              child: Text(LocaleKeys.subscription_signInToBuy.tr()),
            ),
        ],
      ),
    );
  }
}

class _SaveBadge extends StatelessWidget {
  const _SaveBadge({required this.percent, required this.filled});

  final int percent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? theme.colorScheme.primary
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        LocaleKeys.subscription_saveBadge.tr(args: ['$percent']),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: filled
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Русские материалы — надбавка к любому сроку, а не отдельный план.
///
/// Тумблер предвыбран по локальному флагу `russian_content`, которым человек
/// уже ответил на вопрос о языке материалов при первом запуске (см.
/// `SubscriptionBloc`): русскоязычному не приходится догадываться, что русский
/// — отдельная позиция, а выключить её можно одним нажатием.
class _RussianAddon extends StatelessWidget {
  const _RussianAddon({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addon = state.russianAddonRsd;
    final on = state.withRussian;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          context.read<SubscriptionBloc>().add(RussianAddonToggled(!on)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Switch(
              value: on,
              onChanged: (value) => context.read<SubscriptionBloc>().add(
                RussianAddonToggled(value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.subscription_russianAddonTitle.tr(),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    on
                        ? LocaleKeys.subscription_russianAddonOn.tr()
                        : LocaleKeys.subscription_russianAddonOff.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (addon != null) ...[
              const SizedBox(width: 12),
              Text(
                on
                    ? LocaleKeys.subscription_russianAddonPriceOn.tr()
                    : LocaleKeys.subscription_russianAddonPriceOff.tr(
                        args: [amountLabel(addon)],
                      ),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Названия бесплатных категорий — «три категории» ничего не говорит тому, кто
/// ещё не знает структуру экзамена.
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
