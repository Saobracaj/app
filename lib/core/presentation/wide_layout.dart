/// Строительные блоки раскладки для широких экранов (web, десктоп, планшет в
/// ландшафте) по макету веб-версии.
///
/// Макет описывает только desktop/web: всё, что здесь лежит, применяется в
/// ветках `context.isExpandedScreen` / `context.isLargeScreen`, а телефонная
/// вёрстка остаётся прежней. Общий каркас страницы в макете один и тот же —
/// колонка контента шириной до [kWidePageMaxWidth], отступы 40 по бокам,
/// заголовок h1 с подзаголовком, карточки со скруглением 20 и рамкой
/// `outlineVariant` — поэтому он собран здесь, а не переписывается в каждом
/// экране.
library;

import 'package:flutter/material.dart';

import '../responsive.dart';

/// Предельная ширина колонки контента (в макете `max-width:1240px`).
const double kWidePageMaxWidth = 1240;

/// Горизонтальные отступы страницы на широком экране (`padding:… 40px`).
const double kWidePageHorizontalPadding = 40;

/// Скругление карточек-контейнеров (`border-radius:20px`).
const double kWideCardRadius = 20;

/// Фон страницы на широком экране. В макете полотно (`--bg`) заметно темнее
/// карточек (`--surface`), за счёт чего карточки читаются как отдельные
/// поверхности; в Material 3 та же пара — `surfaceContainer` под
/// `surface`.
Color widePageBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainer;

/// Центрирует [child] в колонке шириной [maxWidth] и добавляет отступы
/// страницы. Оборачивать нужно прокручиваемое содержимое целиком.
class WideContent extends StatelessWidget {
  const WideContent({
    super.key,
    this.maxWidth = kWidePageMaxWidth,
    this.padding = const EdgeInsets.fromLTRB(
      kWidePageHorizontalPadding,
      28,
      kWidePageHorizontalPadding,
      64,
    ),
    required this.child,
  });

  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + padding.horizontal),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Заголовок страницы: крошки (необязательно), h1 и подзаголовок.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumbs,
    this.trailing,
    this.bottomSpacing = 28,
  });

  final String title;
  final String? subtitle;

  /// Строка крошек над заголовком («Вопросы / Конспект»).
  final Widget? breadcrumbs;

  /// Действия справа от заголовка (кнопки в одну строку с h1).
  final Widget? trailing;

  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breadcrumbs != null) ...[
          DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: breadcrumbs!,
          ),
          const SizedBox(height: 10),
        ],
        if (trailing == null)
          heading
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              trailing!,
            ],
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

/// Заголовок блока внутри страницы: «Списки вопросов · 5 списков · Создать».
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.hint,
    this.action,
  });

  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(width: 12),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const Spacer(), action!],
        ],
      ),
    );
  }
}

/// Карточка-поверхность макета: `background:var(--surface)` плюс рамка
/// `1px solid var(--ov)` и скругление 16–20.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.radius = kWideCardRadius,
    this.color,
    this.onTap,
    this.dashed = false,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  /// Пунктирная рамка карточки-приглашения («Создать группу»). Настоящий
  /// пунктир Flutter рисовать не умеет без кастомного painter'а, поэтому
  /// вариант отличается прозрачным фоном и цветом рамки `outline`.
  final bool dashed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dashed ? Colors.transparent : (color ?? scheme.surface),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dashed ? scheme.outline : scheme.outlineVariant,
        ),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
  }
}

/// Сетка `repeat(auto-fill, minmax(<min>, 1fr))` из макета: колонок столько,
/// сколько влезает при минимальной ширине элемента [minItemWidth], а остаток
/// ширины распределяется между ними поровну.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.minItemWidth,
    this.spacing = 12,
    this.runSpacing = 12,
    required this.children,
  });

  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final columns = ((available + spacing) / (minItemWidth + spacing))
            .floor()
            .clamp(1, children.length);
        final itemWidth = (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Двухколоночная раскладка «основное + боковая карточка» из макета
/// (`grid-template-columns: minmax(0,1fr) 300px`). Боковая колонка липкая —
/// в Flutter это выражается тем, что она не уезжает вместе с прокруткой
/// основной колонки: каждая колонка скроллится сама.
class MainWithSide extends StatelessWidget {
  const MainWithSide({
    super.key,
    required this.main,
    required this.side,
    this.sideWidth = 300,
    this.gap = 24,
    this.sideFirstWhenStacked = false,
  });

  final Widget main;
  final Widget side;
  final double sideWidth;
  final double gap;

  /// На узком экране (когда колонки складываются) боковой блок обычно уходит
  /// вниз; для экранов, где он несёт главное действие, — наверх.
  final bool sideFirstWhenStacked;

  @override
  Widget build(BuildContext context) {
    if (!context.isExpandedScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sideFirstWhenStacked
            ? [side, SizedBox(height: gap), main]
            : [main, SizedBox(height: gap), side],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: main),
        SizedBox(width: gap),
        SizedBox(width: sideWidth, child: side),
      ],
    );
  }
}

/// Ряд «плиток со числом» из макета результата: крупное значение и подпись.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
