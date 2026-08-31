import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../core/di.dart';
import '../../core/legal_documents.dart';
import '../../core/responsive.dart';
import '../../core/store_links.dart';
import '../../generated/locale_keys.g.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';
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
/// Оплата идёт через стор. В вебе стора нет, поэтому там витрина показывает
/// те же цены как справочные и объясняет, что оформить подписку можно в
/// приложении — ни к какой внешней оплате она не ведёт.
class TariffsPage extends StatelessWidget {
  const TariffsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SubscriptionBloc>(),
      child: Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.subscription_tariffsTitle.tr())),
        body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
          // Снэкбары — только про действия (покупка, восстановление); ошибка
          // загрузки рендерится инлайном ниже.
          listenWhen: (prev, curr) =>
              curr.tariffs.isNotEmpty &&
              ((curr.errorMessage != null &&
                      curr.errorMessage != prev.errorMessage) ||
                  (curr.infoMessage != null &&
                      curr.infoMessage != prev.infoMessage)),
          listener: (context, state) {
            final message = state.errorMessage ?? state.infoMessage;
            if (message == null) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          },
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
            final platform = context.read<SubscriptionBloc>().storePlatform;
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
                if (platform == null) ...[
                  const _BuyInAppCard(),
                  const SizedBox(height: 16),
                ] else if (state.subscription.autoRenewing) ...[
                  const _AlreadyRenewingNote(),
                  const SizedBox(height: 16),
                ],
                _TermRow(state: state, platform: platform),
                const SizedBox(height: 12),
                _RussianAddon(state: state),
                if (platform != null) ...[
                  const SizedBox(height: 12),
                  _RestoreRow(state: state),
                ],
                const SizedBox(height: 28),
                // Тумблер надбавки — над таблицей, поэтому строка «Материалы
                // на русском» показывает уже сделанный выбор, а не «по выбору».
                PlanFeaturesComparison(withRussian: state.withRussian),
                const SizedBox(height: 16),
                const _FreeTierCard(),
                const SizedBox(height: 16),
                _LegalFooter(showRenewalTerms: state.hasAutoRenewingTariff),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Веб: покупать здесь нечего. Карточка говорит, где оформляется подписка, и
/// ведёт в стор — не на внешнюю оплату, а за самим приложением.
class _BuyInAppCard extends StatelessWidget {
  const _BuyInAppCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStore = appStoreUrl;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.subscription_webOnlyTitle.tr(),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.subscription_webOnlyBody.tr(),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (appStore != null)
                  FilledButton.icon(
                    onPressed: () =>
                        launchUrl(appStore, mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.apple, size: 18),
                    label: Text(LocaleKeys.subscription_platformApple.tr()),
                  ),
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    googlePlayUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.shop_outlined, size: 18),
                  label: Text(LocaleKeys.subscription_platformGoogle.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.subscription_referencePriceNote.tr(),
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

/// У человека уже идёт автоподписка, а он смотрит на годовой тариф. Отменить
/// автопродление из приложения нельзя — только в сторе, и сказать об этом надо
/// до покупки, а не после второго списания.
class _AlreadyRenewingNote extends StatelessWidget {
  const _AlreadyRenewingNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manageUrl = context.select(
      (SubscriptionBloc bloc) => bloc.state.subscription.manageUrl,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.subscription_alreadyRenewingWarning.tr(),
            style: theme.textTheme.bodyMedium,
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
      ),
    );
  }
}

/// «Восстановить покупки» — обязательный для сторов путь: подписка привязана к
/// аккаунту стора, а не к устройству.
class _RestoreRow extends StatelessWidget {
  const _RestoreRow({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            LocaleKeys.subscription_restoreHint.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: state.busy
              ? null
              : () => context.read<SubscriptionBloc>().add(
                  PurchasesRestoreRequested(),
                ),
          child: Text(LocaleKeys.subscription_restore.tr()),
        ),
      ],
    );
  }
}

/// Ссылки на условия использования (там же условия оплаты и возврата) и
/// политику конфиденциальности — обязательная преддоговорная информация. Для
/// автопродлеваемой подписки к ним добавляется формулировка условий продления,
/// которую требуют оба стора.
class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.showRenewalTerms});

  final bool showRenewalTerms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showRenewalTerms) ...[
          Text(
            LocaleKeys.subscription_autoRenewDisclosure.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          LocaleKeys.subscription_legalNote.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            _LegalLink(
              label: LocaleKeys.info_termsOfUse.tr(),
              uri: legalDocumentUri(LegalDocument.termsOfUse, lang),
            ),
            _LegalLink(
              label: LocaleKeys.info_privacyPolicy.tr(),
              uri: legalDocumentUri(LegalDocument.privacyPolicy, lang),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
    );
  }
}

/// Три срока рядом. На узком экране — стопкой, самый выгодный первым: на
/// телефоне порядок и есть рекомендация.
class _TermRow extends StatelessWidget {
  const _TermRow({required this.state, required this.platform});

  final SubscriptionState state;
  final StorePlatform? platform;

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
          platform: platform,
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
    required this.platform,
    required this.recommended,
  });

  final Tariff tariff;
  final SubscriptionState state;
  final StorePlatform? platform;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authenticated = context.select(
      (AuthBloc bloc) => bloc.state.isAuthenticated,
    );
    final product = state.storeProductFor(tariff, platform);
    final saving = state.savingPercent(tariff, platform);
    final savedRsd = state.savingRsd(tariff);
    final perMonth = perMonthLabel(tariff, product);
    final buying = state.purchasingSku == tariff.sku;

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
              if (saving != null && saving > 0)
                _SaveBadge(percent: saving, filled: recommended),
            ],
          ),
          const SizedBox(height: 12),
          if (perMonth != null) ...[
            Text(
              perMonth,
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
          ],
          Text(
            LocaleKeys.subscription_payTotal.tr(
              args: [totalPriceLabel(tariff, product)],
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            // У месячного тарифа «экономии» нет — вместо неё главное про него:
            // он продлевается сам. Это и есть довод в пользу года.
            tariff.autoRenewing
                ? LocaleKeys.subscription_autoRenewNote.tr()
                : savedRsd == null || savedRsd <= 0
                ? LocaleKeys.subscription_oneOffNote.tr()
                : LocaleKeys.subscription_savingNote.tr(
                    args: [amountLabel(savedRsd)],
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (platform == null)
            // Веб: кнопки покупки нет вовсе — ни к какой оплате отсюда не
            // ведём, об этом сказано карточкой наверху.
            const SizedBox.shrink()
          else if (!authenticated)
            OutlinedButton(
              onPressed: () => Routemaster.of(context).push('/login'),
              child: Text(LocaleKeys.subscription_signInToBuy.tr()),
            )
          else
            _BuyButton(
              tariff: tariff,
              recommended: recommended,
              enabled: state.storeAvailable && !state.busy,
              busy: buying,
            ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.tariff,
    required this.recommended,
    required this.enabled,
    required this.busy,
  });

  final Tariff tariff;
  final bool recommended;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onPressed = enabled
        ? () => context.read<SubscriptionBloc>().add(
            PurchaseRequested(tariff.sku),
          )
        : null;
    final label = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(LocaleKeys.subscription_buy.tr());
    return recommended
        ? FilledButton(onPressed: onPressed, child: label)
        : OutlinedButton(onPressed: onPressed, child: label);
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
            // Заголовок со звёздочкой — та же, что стоит у «N категорий» в
            // таблице выше: она и связывает ячейку с этим объяснением.
            Text(
              freeCategoriesFootnoteTitle(),
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
