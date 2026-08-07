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

/// Centers [child] inside [maxWidth] once the screen is wider than that, and
/// is a no-op on phones — the standard wrapper that keeps full-width phone
/// scrollables from stretching edge-to-edge on tablets and web.
///
/// Wrap the *scrollable* (ListView and the like), not its items — item-level
/// wrapping breaks ink splashes and separators that expect the list's full
/// width. The side gutters this leaves are plain Scaffold background.
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
