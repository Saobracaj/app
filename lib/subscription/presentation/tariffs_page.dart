import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/state_management/auth/auth_bloc.dart';
import '../../core/di.dart';
import '../../core/legal_documents.dart';
import '../../core/responsive.dart';
import '../../core/store_links.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';
import '../../theme/quiz_colors.dart';
import '../models/subscription_models.dart';
import '../state_management/subscription_bloc.dart';
import '../state_management/subscription_events.dart';
import '../state_management/subscription_state.dart';
import 'plan_features.dart';
import 'tariff_formatting.dart';

/// Витрина тарифов — она же экран пейволла: один пропуск Premium, срок
/// выбирается переключателем.
///
/// Три карточки в ряд заменены переключателем срока и одной карточкой: экран
/// перестаёт расти вместе с числом сроков, а всё, что человек должен знать до
/// нажатия, помещается без прокрутки. Тип платежа назван словами («Подписка» /
/// «Разовый платёж») — это единственное настоящее различие между сроками, и
/// узнавать о нём из мелкой подписи под ценой человек не должен.
///
/// Крупная цифра — полная сумма, которая спишется сейчас, а не цена за месяц:
/// цена за месяц стоит второй строкой, как объяснение выгоды. Кнопка повторяет
/// эту же сумму, чтобы окно стора не показало ничего нового.
///
/// Тариф один, русские материалы входят в любой пропуск — ни тумблеров, ни
/// второго ряда цен. Подробное сравнение с бесплатным уровнем уехало за ссылку
/// ([PlanFeaturesComparison] в шторке): до покупки оно нужно единицам, а места
/// занимало больше, чем сами цены.
///
/// Оплата идёт через стор. В вебе стора нет, поэтому там витрина показывает те
/// же цены как справочные и объясняет, что оформить подписку можно в
/// приложении, — ни к какой внешней оплате она не ведёт.
class TariffsPage extends StatelessWidget {
  const TariffsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SubscriptionBloc>(),
      child: const _TariffsScaffold(),
    );
  }
}

/// Держит выбранный срок. Виджет стоит **над** `BlocConsumer`: выбор человека
/// не должен сбрасываться на рекомендованный от каждого нового состояния —
/// например, когда стор дочитал цены.
class _TariffsScaffold extends StatefulWidget {
  const _TariffsScaffold();

  @override
  State<_TariffsScaffold> createState() => _TariffsScaffoldState();
}

class _TariffsScaffoldState extends State<_TariffsScaffold> {
  String? _selectedSku;

  /// Выбранный срок, а пока человек не выбирал — рекомендованный. Ищем по SKU,
  /// а не храним сам тариф: каталог приезжает асинхронно и пересоздаётся.
  Tariff? _selected(SubscriptionState state) {
    final offered = state.offeredTariffs;
    if (offered.isEmpty) return null;
    for (final tariff in offered) {
      if (tariff.sku == _selectedSku) return tariff;
    }
    return state.recommendedTariff ?? offered.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          final selected = _selected(state);
          if (selected == null) {
            return _LoadFailed(
              message: state.errorMessage,
              onRetry: () =>
                  context.read<SubscriptionBloc>().add(SubscriptionRequested()),
            );
          }
          final platform = context.read<SubscriptionBloc>().storePlatform;
          final wide = context.isMediumScreen;

          final segments = _TermSegments(
            state: state,
            platform: platform,
            selected: selected,
            onChanged: (tariff) => setState(() => _selectedSku = tariff.sku),
          );
          final card = _PlanCard(
            tariff: selected,
            state: state,
            platform: platform,
          );
          const features = _FeaturesCard();
          // Условия автопродления — там, где продлевается: на разовом пропуске
          // это чужая сноска, а месячный человек видит её в тот же миг, когда
          // выбирает.
          final legal = _LegalFooter(showRenewalTerms: selected.autoRenewing);

          // Список во всю ширину, поля — в его padding: полоса прокрутки тогда
          // идёт по краю окна, а не посреди экрана, и колесо мыши работает над
          // любой точкой страницы, а не только над колонкой.
          return ListView(
            padding: readableInsets(
              context,
              maxWidth: wide ? 1000 : kReadableContentWidth,
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
              // Переключатель стоит над обеими колонками, но во всю ширину
              // десктопа не растягивается: три кнопки на тысячу точек — это
              // уже не переключатель, а меню.
              //
              // `Align`, а не голый `ConstrainedBox`: элемент списка получает
              // тугую ширину, и `maxWidth` внутри неё просто не с чем спорить.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: segments,
                ),
              ),
              const SizedBox(height: 12),
              if (wide)
                // Без `IntrinsicHeight`: колонки меряются собственным
                // содержимым, а список возможностей внутри строит сетку через
                // `LayoutBuilder`, которому промежуточные размеры не посчитать.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 21, child: card),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [features, const SizedBox(height: 16), legal],
                      ),
                    ),
                  ],
                )
              else ...[
                card,
                const SizedBox(height: 12),
                features,
                const SizedBox(height: 16),
                legal,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Переключатель срока. Значок «Популярный» / «−N%» висит над кнопкой, а не
/// внутри неё: внутри он съедал бы место у самой подписи срока, которая на
/// сербском и так длинная.
class _TermSegments extends StatelessWidget {
  const _TermSegments({
    required this.state,
    required this.platform,
    required this.selected,
    required this.onChanged,
  });

  final SubscriptionState state;
  final StorePlatform? platform;
  final Tariff selected;
  final ValueChanged<Tariff> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tariffs = state.offeredTariffs;
    final recommended = state.recommendedTariff;
    return Padding(
      // Место значку, который выступает над переключателем.
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            for (var i = 0; i < tariffs.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _TermSegment(
                  tariff: tariffs[i],
                  selected: tariffs[i].sku == selected.sku,
                  badge: _badgeFor(tariffs[i], recommended),
                  onTap: () => onChanged(tariffs[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Рекомендованному сроку — «Популярный», остальным длинным — процент
  /// экономии. Месячный не подписан ничем: он и есть база сравнения.
  String? _badgeFor(Tariff tariff, Tariff? recommended) {
    if (tariff.sku == recommended?.sku) {
      return LocaleKeys.subscription_popularBadge.tr();
    }
    final percent = state.savingPercent(tariff, platform);
    if (percent == null || percent <= 0) return null;
    return LocaleKeys.subscription_saveBadge.tr(args: ['$percent']);
  }
}

class _TermSegment extends StatelessWidget {
  const _TermSegment({
    required this.tariff,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final Tariff tariff;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = monthsLabel(tariff.months);
    return Semantics(
      button: true,
      selected: selected,
      // Значок — часть подписи для скринридера: визуально он к этой кнопке
      // и относится, хотя нарисован над ней.
      label: badge == null ? label : '$label, $badge',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            elevation: selected ? 1 : 0,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            PositionedDirectional(
              top: -9,
              end: 6,
              child: _SegmentBadge(text: badge!),
            ),
        ],
      ),
    );
  }
}

class _SegmentBadge extends StatelessWidget {
  const _SegmentBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: quiz.correctContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: quiz.onCorrectContainer,
        ),
      ),
    );
  }
}

/// Карточка выбранного срока: что это за платёж, сколько списывается сейчас,
/// во что это выходит помесячно и что будет дальше.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tariff,
    required this.state,
    required this.platform,
  });

  final Tariff tariff;
  final SubscriptionState state;
  final StorePlatform? platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiz = theme.quiz;
    final wide = context.isMediumScreen;
    final authenticated = context.select(
      (AuthBloc bloc) => bloc.state.isAuthenticated,
    );
    final product = state.storeProductFor(tariff, platform);
    final total = totalPriceLabel(tariff, product);
    final perMonth = perMonthLabel(tariff, product);
    final saving = state.saving(tariff, platform);

    return Container(
      padding: EdgeInsets.fromLTRB(
        wide ? 28 : 18,
        wide ? 26 : 18,
        wide ? 28 : 18,
        wide ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KindBadge(autoRenewing: tariff.autoRenewing),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.subscription_payNow.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          // Полная сумма, а не цена за месяц: это то, что спишется сейчас.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              total,
              style:
                  (wide
                          ? theme.textTheme.displayMedium
                          : theme.textTheme.displaySmall)
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.5,
                      ),
            ),
          ),
          const SizedBox(height: 6),
          if (perMonth != null) _PerMonthLine(tariff: tariff, amount: perMonth),
          if (saving != null) ...[
            const SizedBox(height: 4),
            Text(
              LocaleKeys.subscription_savingAgainstMonthly.tr(
                args: [savingAmountLabel(saving)],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: quiz.correct,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            tariff.autoRenewing
                ? LocaleKeys.subscription_autoRenewCardNote.tr()
                : LocaleKeys.subscription_oneOffCardNote.tr(
                    args: [monthsLabel(tariff.months)],
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (platform == null)
            // Веб: кнопки покупки нет вовсе — ни к какой оплате отсюда не
            // ведём, об этом сказано карточкой наверху.
            const SizedBox.shrink()
          else if (!authenticated)
            _WideButton(
              child: OutlinedButton(
                onPressed: () => Routemaster.of(context).push('/login'),
                child: Text(LocaleKeys.subscription_signInToBuy.tr()),
              ),
            )
          else
            _WideButton(
              child: _BuyButton(
                tariff: tariff,
                label: tariff.autoRenewing
                    ? LocaleKeys.subscription_buySubscription.tr()
                    : LocaleKeys.subscription_payAmount.tr(args: [total]),
                enabled: state.storeAvailable && !state.busy,
                busy: state.purchasingSku == tariff.sku,
              ),
            ),
        ],
      ),
    );
  }
}

/// «8,33 € в месяц · 3 месяца доступа» — цена за месяц выделена, срок подписан
/// приглушённо: сравнивают сроки по первому числу, а второе только уточняет,
/// за что оно.
class _PerMonthLine extends StatelessWidget {
  const _PerMonthLine({required this.tariff, required this.amount});

  final Tariff tariff;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: LocaleKeys.subscription_perMonthAmount.tr(args: [amount]),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          // У месячного пропуска срок повторять незачем — он уже назван.
          if (tariff.months > 1)
            TextSpan(
              text:
                  ' · '
                  '${LocaleKeys.subscription_accessFor.tr(args: [monthsLabel(tariff.months)])}',
            ),
        ],
      ),
      style: muted,
    );
  }
}

/// Тип платежа словами. Разница между «спишется ещё раз через месяц» и «больше
/// не спишется» — единственная, ради которой стоит читать эту карточку до
/// конца, поэтому она стоит первой строкой.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.autoRenewing});

  final bool autoRenewing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = autoRenewing
        ? LocaleKeys.subscription_kindSubscription.tr()
        : LocaleKeys.subscription_kindOneOff.tr();
    final renewal = autoRenewing
        ? LocaleKeys.subscription_kindAutoRenew.tr()
        : LocaleKeys.subscription_kindNoAutoRenew.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$kind · $renewal',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка во всю ширину карточки и ростом с кнопку стора: до неё дочитывают, а
/// не доводят курсор.
class _WideButton extends StatelessWidget {
  const _WideButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: 52, child: child);
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({
    required this.tariff,
    required this.label,
    required this.enabled,
    required this.busy,
  });

  final Tariff tariff;
  final String label;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onPressed = enabled
        ? () => context.read<SubscriptionBloc>().add(
            PurchaseRequested(tariff.sku),
          )
        : null;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// «Что открывается» — короткий список в две колонки. Подробное сравнение с
/// бесплатным уровнем спрятано за ссылкой: тому, кто пришёл за ценой, нужен
/// перечень, а не таблица.
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = planFeatureRows();
    // Всегда открытое (обсуждения, поиск, чат с разработчиком) — не то, что
    // «открывается»: оно уходит в подпись под списком.
    final unlocked = [
      for (final row in rows)
        if (row.free != PlanAccess.always) row.title,
    ];
    final always = [
      for (final row in rows)
        if (row.free == PlanAccess.always) row.title,
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.isMediumScreen ? 24 : 16,
        context.isMediumScreen ? 20 : 14,
        context.isMediumScreen ? 24 : 16,
        context.isMediumScreen ? 18 : 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.subscription_featuresOpenTitle.tr().toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _BulletGrid(items: unlocked),
          if (always.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Bullet(
              text: LocaleKeys.subscription_featuresAllNote.tr(
                args: [always.join(', ')],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const _FreeTierLine(),
        ],
      ),
    );
  }
}

/// Список в две колонки, а на совсем узком — в одну: два столбца по 150 px
/// режут подписи на слова.
class _BulletGrid extends StatelessWidget {
  const _BulletGrid({required this.items});

  final List<String> items;

  static const _gap = 14.0;
  static const _minColumn = 150.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _minColumn * 2 + _gap ? 2 : 1;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - _gap) / 2;
        return Wrap(
          spacing: _gap,
          runSpacing: 6,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _Bullet(text: item),
              ),
          ],
        );
      },
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// Бесплатный уровень одной строкой плюс ссылка на подробное сравнение.
class _FreeTierLine extends StatelessWidget {
  const _FreeTierLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = LocaleKeys.subscription_valueFreeCategories.plural(
      freeCategoryIds.length,
    );
    return _LinkedParagraph(
      template:
          '${LocaleKeys.subscription_freeShort.tr(args: [categories])} {compare}',
      links: {
        'compare': (
          LocaleKeys.subscription_compareToFree.tr(),
          () => _showPlanComparison(context),
        ),
      },
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
    );
  }
}

/// Подробное сравнение «бесплатно / по подписке» — шторкой поверх витрины.
/// Отдельным экраном оно не стоит: из него всё равно возвращаются к ценам.
void _showPlanComparison(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: readableInsets(context, maxWidth: 900, top: 4, bottom: 32),
        children: [
          const PlanFeaturesComparison(),
          const SizedBox(height: 20),
          const _FreeTierCard(),
        ],
      ),
    ),
  );
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
                    onPressed: () => launchUrl(
                      appStore,
                      mode: LaunchMode.externalApplication,
                    ),
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

/// Ссылки на условия использования (там же условия оплаты и возврата) и
/// политику конфиденциальности — обязательная преддоговорная информация. Для
/// автопродлеваемой подписки к ним добавляется формулировка условий продления,
/// которую требуют оба стора.
///
/// Ссылки стоят прямо в предложении, а не кнопками под ним: это сноска, а не
/// действие, которое кому-то предлагают совершить.
class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.showRenewalTerms});

  final bool showRenewalTerms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showRenewalTerms) ...[
          Text(LocaleKeys.subscription_autoRenewDisclosure.tr(), style: style),
          const SizedBox(height: 8),
        ],
        _LinkedParagraph(
          template:
              '${LocaleKeys.subscription_legalStoreNote.tr()} '
              '${LocaleKeys.subscription_legalAcceptNote.tr()}',
          links: {
            'terms': (
              LocaleKeys.subscription_legalTermsLink.tr(),
              () => launchUrl(
                legalDocumentUri(LegalDocument.termsOfUse, lang),
                mode: LaunchMode.externalApplication,
              ),
            ),
            'privacy': (
              LocaleKeys.subscription_legalPrivacyLink.tr(),
              () => launchUrl(
                legalDocumentUri(LegalDocument.privacyPolicy, lang),
                mode: LaunchMode.externalApplication,
              ),
            ),
          },
          style: style,
        ),
      ],
    );
  }
}

/// Абзац, в котором часть слов — ссылки: шаблон режется по меткам вида
/// `{terms}`, и на месте каждой встаёт кликабельный отрезок.
///
/// Метки, а не склейка кусков в коде: порядок ссылок в предложении задаёт
/// перевод, и в сербском он не такой, как в русском.
class _LinkedParagraph extends StatefulWidget {
  const _LinkedParagraph({
    required this.template,
    required this.links,
    this.style,
  });

  final String template;
  final Map<String, (String label, VoidCallback onTap)> links;
  final TextStyle? style;

  @override
  State<_LinkedParagraph> createState() => _LinkedParagraphState();
}

class _LinkedParagraphState extends State<_LinkedParagraph> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final theme = Theme.of(context);
    final linkStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );
    final pattern = RegExp('\\{(${widget.links.keys.join('|')})\\}');
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in pattern.allMatches(widget.template)) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: widget.template.substring(index, match.start)),
        );
      }
      final (label, onTap) = widget.links[match.group(1)]!;
      final recognizer = TapGestureRecognizer()..onTap = onTap;
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: label, style: linkStyle, recognizer: recognizer),
      );
      index = match.end;
    }
    if (index < widget.template.length) {
      spans.add(TextSpan(text: widget.template.substring(index)));
    }
    return Text.rich(TextSpan(children: spans), style: widget.style);
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
