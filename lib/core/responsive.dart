import 'package:flutter/widgets.dart';

/// Width breakpoints of the adaptive layout, after Material 3 window size
/// classes. Mobile layouts are the baseline and stay untouched below
/// [medium]; wider windows (tablets, landscape, web) progressively rearrange
/// the chrome instead of stretching phone layouts across the whole screen.
abstract final class Breakpoints {
  /// Tablet portrait / small landscape: content gets a readable max width,
  /// the home tabs move into a navigation rail.
  static const double medium = 600;

  /// Tablet landscape / desktop: screens with side content (the question
  /// screen's feature tabs) switch to a two-pane layout.
  static const double expanded = 840;

  /// Wide desktop: the navigation rail expands into labeled destinations.
  static const double large = 1200;
}

/// Text longer than this is uncomfortable to read — scrollable text content
/// is centered inside this width on wide screens.
const double kReadableContentWidth = 720;

extension ResponsiveContext on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  /// At least tablet-sized — the phone layout stops being the right answer.
  bool get isMediumScreen => _width >= Breakpoints.medium;

  /// Wide enough for side-by-side panes.
  bool get isExpandedScreen => _width >= Breakpoints.expanded;

  /// Wide enough for the extended navigation rail.
  bool get isLargeScreen => _width >= Breakpoints.large;
}

/// Горизонтальные поля, центрирующие содержимое скроллируемого в [maxWidth],
/// не сужая сам скроллируемый.
///
/// Альтернатива [ReadableWidth] там, где важно поведение прокрутки: [ReadableWidth]
/// сужает сам список, поэтому и полоса прокрутки, и колесо мыши работают только
/// внутри узкой колонки — полоса оказывается посреди экрана, а над полями
/// страница не крутится. Если вместо этого оставить список во всю ширину и
/// раздать поля через `padding`, полоса встаёт у края окна, а колесо работает в
/// любом месте страницы.
///
/// Цена — та самая, о которой предупреждает [ReadableWidth]: элементы больше не
/// знают полной ширины списка, так что разделители и подсветка нажатия
/// заканчиваются по краю содержимого, а не окна. Для экранов из карточек это
/// незаметно, для длинных списков со `Divider` — нет.
///
/// [availableWidth] задаёт ширину области, внутри которой центрируется колонка,
/// когда это не всё окно, — например, если рядом стоит закреплённая колонка с
/// оглавлением.
EdgeInsets readableInsets(
  BuildContext context, {
  double maxWidth = kReadableContentWidth,
  double horizontal = 16,
  double top = 0,
  double bottom = 0,
  double? availableWidth,
}) {
  final free =
      ((availableWidth ?? MediaQuery.sizeOf(context).width) - maxWidth) / 2;
  final gutter = free > horizontal ? free : horizontal;
  return EdgeInsets.fromLTRB(gutter, top, gutter, bottom);
}

/// Centers [child] inside [maxWidth] once the screen is wider than that, and
/// is a no-op on phones — the standard wrapper that keeps full-width phone
/// scrollables from stretching edge-to-edge on tablets and web.
///
/// Wrap the *scrollable* (ListView and the like), not its items — item-level
/// wrapping breaks ink splashes and separators that expect the list's full
/// width. The side gutters this leaves are plain Scaffold background.
///
/// Если полоса прокрутки должна идти по краю окна, а не по краю колонки,
/// используйте [readableInsets] вместо этого виджета.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    this.maxWidth = kReadableContentWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
