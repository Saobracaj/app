import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Вертикальная прокрутка вокруг виджета — минуя горизонтальные [PageView]
/// по дороге (листалка вопросов, страницы вкладок под вопросом).
///
/// У виджета внутри такой страницы «ближайшие» [Scrollable] и viewport —
/// горизонтальные, и мерить по ним «докрутил ли читатель до низа» или
/// «покажи меня на экране» нельзя: [Scrollable.maybeOf] без оси отдаёт
/// листалку, а [Scrollable.ensureVisible] считает смещение по ближайшему
/// viewport и применяет его к каждой объемлющей прокрутке по очереди — в том
/// числе к листалке вопросов, которой вертикальное смещение ни о чём не
/// говорит. Здесь — только вертикальная ось.

/// Ближайшая вертикальная прокрутка вокруг [context], если она есть.
ScrollableState? verticalScrollableOf(BuildContext context) =>
    Scrollable.maybeOf(context, axis: Axis.vertical);

/// Ближайший вертикальный viewport над [object], если он есть.
RenderViewportBase? verticalViewportOf(RenderObject object) {
  RenderObject? node = object.parent;
  while (node != null) {
    if (node is RenderViewportBase && node.axis == Axis.vertical) return node;
    node = node.parent;
  }
  return null;
}

/// Прокручивает ближайшую вертикальную прокрутку так, чтобы [context] оказался
/// на экране: [alignment] 0 — у верхнего края, 1 — у нижнего, 0.3 — на трети.
/// Без вертикальной прокрутки вокруг ничего не делает.
Future<void> revealVertically(
  BuildContext context, {
  double alignment = 0.0,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) async {
  final scrollable = verticalScrollableOf(context);
  final object = context.findRenderObject();
  if (scrollable == null || object == null || !object.attached) return;
  final viewport = verticalViewportOf(object);
  if (viewport == null) return;
  final position = scrollable.position;
  if (!position.hasPixels || !position.hasContentDimensions) return;
  final target = viewport
      .getOffsetToReveal(object, alignment)
      .offset
      .clamp(position.minScrollExtent, position.maxScrollExtent);
  if (target == position.pixels) return;
  if (duration == Duration.zero) {
    position.jumpTo(target);
    return;
  }
  await position.animateTo(target, duration: duration, curve: curve);
}
