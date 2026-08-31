/// Что человек получает бесплатно и что открывает подписка — одним списком.
///
/// Экран тарифов существует только в вебе (App Store 3.1.3(b) не разрешает ни
/// цен, ни ссылок на внешнюю оплату), поэтому объяснение «что вообще бывает
/// платного» живёт **отдельно от цен**: этот виджет можно показать и там, где
/// цену называть нельзя, — у замка, в настройках.
///
/// Ключевое отличие бесплатного уровня от платного — не набор функций, а объём
/// контента: те же объяснения, конспекты и анализ либо в трёх бесплатных
/// категориях (`freeCategoryIds`), либо во всех. Поэтому в ячейках стоит
/// количество, а не галочка.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../feature_flags/domain/app_feature.dart';
import '../../generated/locale_keys.g.dart';

/// Насколько функция открыта на данном уровне.
enum PlanAccess {
  /// Во всех категориях.
  all,

  /// Только в бесплатных категориях.
  freeCategories,

  /// Не входит.
  none,

  /// Входит по выбору — надбавка за русские материалы.
  optional,

  /// Открыто всегда и всем, срока и категорий не касается.
  always,
}

/// Строка сравнения: что за функция и как она открыта на каждом уровне.
class PlanFeatureRow {
  const PlanFeatureRow({
    required this.title,
    required this.hint,
    required this.free,
    required this.paid,
  });

  final String title;
  final String hint;
  final PlanAccess free;
  final PlanAccess paid;
}

/// Строки витрины. Порядок — от того, что человек уже трогает каждый день, к
/// тому, ради чего платят.
List<PlanFeatureRow> planFeatureRows() => [
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureQuestions.tr(),
    hint: LocaleKeys.subscription_featureQuestionsHint.tr(),
    free: PlanAccess.all,
    paid: PlanAccess.all,
  ),
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureExplanations.tr(),
    hint: LocaleKeys.subscription_featureExplanationsHint.tr(),
    free: PlanAccess.freeCategories,
    paid: PlanAccess.all,
  ),
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureKonspekts.tr(),
    hint: LocaleKeys.subscription_featureKonspektsHint.tr(),
    free: PlanAccess.freeCategories,
    paid: PlanAccess.all,
  ),
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureAnalysis.tr(),
    hint: LocaleKeys.subscription_featureAnalysisHint.tr(),
    free: PlanAccess.freeCategories,
    paid: PlanAccess.all,
  ),
  // Чат с AI — единственная премиум-функция, которую бесплатные категории не
  // открывают: у неё переменная стоимость за сообщение
  // (`AppFeature.askAi.freeInFreeCategories == false`).
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureAskAi.tr(),
    hint: LocaleKeys.subscription_featureAskAiHint.tr(),
    free: PlanAccess.none,
    paid: PlanAccess.all,
  ),
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureRussian.tr(),
    hint: LocaleKeys.subscription_featureRussianHint.tr(),
    free: PlanAccess.freeCategories,
    paid: PlanAccess.optional,
  ),
  PlanFeatureRow(
    title: LocaleKeys.subscription_featureCommunity.tr(),
    hint: LocaleKeys.subscription_featureCommunityHint.tr(),
    free: PlanAccess.always,
    paid: PlanAccess.always,
  ),
];

/// Знак сноски у «в N категориях»: само число ничего не говорит тому, кто не
/// знает структуру экзамена, а звёздочка ведёт к карточке «Что доступно
/// бесплатно» — там эти категории названы поимённо
/// ([freeCategoriesFootnoteTitle]).
const freeCategoriesFootnoteMark = '*';

/// Заголовок карточки, к которой ведёт звёздочка, — с тем же знаком впереди.
String freeCategoriesFootnoteTitle() =>
    '$freeCategoriesFootnoteMark\u2009${LocaleKeys.subscription_freeTitle.tr()}';

String planAccessLabel(PlanAccess access) => switch (access) {
  PlanAccess.all => LocaleKeys.subscription_valueAllCategories.tr(),
  PlanAccess.freeCategories =>
    '${LocaleKeys.subscription_valueFreeCategories.plural(freeCategoryIds.length)}'
        '$freeCategoriesFootnoteMark',
  PlanAccess.none => LocaleKeys.subscription_valueNone.tr(),
  PlanAccess.optional => LocaleKeys.subscription_valueOption.tr(),
  PlanAccess.always => LocaleKeys.subscription_valueAlways.tr(),
};

/// Сравнение «бесплатно / по подписке». На узком экране таблица из трёх колонок
/// нечитаема, поэтому там — те же строки списком.
class PlanFeaturesComparison extends StatelessWidget {
  const PlanFeaturesComparison({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = planFeatureRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (context.isMediumScreen)
          _FeatureTable(rows: rows)
        else
          _FeatureList(rows: rows),
        const SizedBox(height: 12),
        const _Legend(),
      ],
    );
  }
}

class _FeatureTable extends StatelessWidget {
  const _FeatureTable({required this.rows});

  final List<PlanFeatureRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = BorderSide(color: theme.colorScheme.outlineVariant);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: divider)),
              children: [
                _HeadCell(
                  LocaleKeys.subscription_featuresTitle.tr(),
                  inset: _labelColumnInset,
                ),
                _HeadCell(
                  LocaleKeys.subscription_columnFree.tr(),
                  inset: _valueColumnInset,
                ),
                _HeadCell(
                  LocaleKeys.subscription_columnPaid.tr(),
                  inset: _valueColumnInset,
                  highlighted: true,
                ),
              ],
            ),
            for (var i = 0; i < rows.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  border: i == rows.length - 1 ? null : Border(bottom: divider),
                ),
                children: [
                  // Высоту строки задаёт эта ячейка — она самая высокая
                  // (название плюс подпись), остальные тянутся под неё.
                  _LabelCell(row: rows[i]),
                  _ValueCell(access: rows[i].free),
                  _ValueCell(access: rows[i].paid, highlighted: true),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Отступы столбцов таблицы. Заголовок и значения одного столбца отступают
/// одинаково: кружки всех строк и подпись столбца должны стоять на одной
/// вертикали — иначе взгляд не собирает столбец в столбец.
const double _labelColumnInset = 16;
const double _valueColumnInset = 12;

/// Подсветка платной колонки — тот же контейнер, что у выбранного тарифа.
Color _paidTint(BuildContext context) => Color.alphaBlend(
  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .32),
  Theme.of(context).colorScheme.surface,
);

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.text, {required this.inset, this.highlighted = false});

  final String text;
  final double inset;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: highlighted ? _paidTint(context) : null,
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: 14),
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.start,
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: .8,
          fontWeight: FontWeight.w600,
          color: highlighted
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LabelCell extends StatelessWidget {
  const _LabelCell({required this.row});

  final PlanFeatureRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _labelColumnInset,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.title, style: theme.textTheme.bodyMedium),
          Text(
            row.hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.access, this.highlighted = false});

  final PlanAccess access;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = access == PlanAccess.none;
    // `fill` вместо `middle`: подсветка платного столбца должна доходить до
    // разделителей, иначе столбец распадается на отдельные плашки.
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: highlighted ? _paidTint(context) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: _valueColumnInset,
          vertical: 12,
        ),
        child: Row(
          children: [
            AccessMark(access: access),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                planAccessLabel(access),
                textAlign: TextAlign.start,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted
                      ? theme.colorScheme.onSurfaceVariant.withValues(alpha: .6)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.rows});

  final List<PlanFeatureRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeatureListCard(
          title: LocaleKeys.subscription_columnPaid.tr(),
          rows: rows,
          highlighted: true,
          accessOf: (row) => row.paid,
        ),
        const SizedBox(height: 12),
        _FeatureListCard(
          title: LocaleKeys.subscription_columnFree.tr(),
          rows: rows,
          highlighted: false,
          accessOf: (row) => row.free,
        ),
      ],
    );
  }
}

class _FeatureListCard extends StatelessWidget {
  const _FeatureListCard({
    required this.title,
    required this.rows,
    required this.highlighted,
    required this.accessOf,
  });

  final String title;
  final List<PlanFeatureRow> rows;
  final bool highlighted;
  final PlanAccess Function(PlanFeatureRow row) accessOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? _paidTint(context) : theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            _FeatureListRow(row: row, access: accessOf(row)),
            if (row != rows.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FeatureListRow extends StatelessWidget {
  const _FeatureListRow({required this.row, required this.access});

  final PlanFeatureRow row;
  final PlanAccess access;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = access == PlanAccess.none;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: AccessMark(access: access),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: row.title),
                TextSpan(
                  text: ' — ${planAccessLabel(access)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: .7)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Кружок слева от значения: закрашенный — всё открыто, половина — только
/// бесплатные категории, контур — не входит, полупрозрачный — надбавка.
/// Уровень доступа не должен читаться одним лишь текстом.
class AccessMark extends StatelessWidget {
  const AccessMark({super.key, required this.access});

  final PlanAccess access;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Половина закрашена — «только бесплатные категории»: доступ есть, но не
    // везде. Цветом такое не показать, а формой — да.
    final half = access == PlanAccess.freeCategories;
    final border = switch (access) {
      PlanAccess.all || PlanAccess.always => null,
      PlanAccess.none => Border.all(color: scheme.outline, width: 1.5),
      PlanAccess.freeCategories ||
      PlanAccess.optional => Border.all(color: scheme.primary, width: 1.5),
    };
    return SizedBox(
      width: 13,
      height: 13,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: half
              ? null
              : switch (access) {
                  PlanAccess.all || PlanAccess.always => scheme.primary,
                  PlanAccess.optional => scheme.primary.withValues(alpha: .22),
                  PlanAccess.none => Colors.transparent,
                  PlanAccess.freeCategories => Colors.transparent,
                },
          border: border,
          gradient: half
              ? LinearGradient(
                  colors: [scheme.primary, scheme.primary, Colors.transparent],
                  stops: const [0, .5, .5],
                )
              : null,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(PlanAccess, String)>[
      (PlanAccess.all, LocaleKeys.subscription_legendFull.tr()),
      (PlanAccess.freeCategories, LocaleKeys.subscription_legendPart.tr()),
      (PlanAccess.optional, LocaleKeys.subscription_legendOption.tr()),
      (PlanAccess.none, LocaleKeys.subscription_legendNone.tr()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 20,
        runSpacing: 6,
        children: [
          for (final (access, label) in items)
            // Без верхней границы подпись растягивает Row шире экрана: Wrap
            // переносит целые элементы, а не их содержимое.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccessMark(access: access),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
