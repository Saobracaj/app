import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/app_feature.dart';
import '../state_management/feature_flags_bloc.dart';
import '../state_management/feature_flags_state.dart';

/// Shows [child] only while [feature] is enabled for the current user, and
/// [placeholder] (an empty box by default) otherwise.
///
/// Wraps a [BlocBuilder] on [FeatureFlagsBloc] so callers don't repeat the
/// `context.select(...)`/`isEnabled(...)` dance at every gated widget. The
/// builder only rebuilds when *this* feature's on/off decision changes.
class FeatureGate extends StatelessWidget {
  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.categoryId,
    this.placeholder = const SizedBox.shrink(),
  });

  /// The feature that must be enabled for [child] to be shown.
  final AppFeature feature;

  /// The category of the question this content belongs to, when there is one.
  /// The free categories (25/26/28) open the premium content features for
  /// everybody — see [FeatureFlagsSnapshot.isEnabledForCategory]. Leave `null`
  /// for content that is not attached to a question.
  final String? categoryId;

  /// Rendered when [feature] is enabled.
  final Widget child;

  /// Rendered when [feature] is disabled.
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureFlagsBloc, FeatureFlagsState>(
      buildWhen: (prev, curr) =>
          prev.isEnabledForCategory(feature, categoryId) !=
          curr.isEnabledForCategory(feature, categoryId),
      builder: (context, state) =>
          state.isEnabledForCategory(feature, categoryId) ? child : placeholder,
    );
  }
}
