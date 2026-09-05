import 'package:flutter/foundation.dart';

import '../domain/app_feature.dart';

/// An immutable resolved view of every feature for the current user, published
/// by [FeatureFlagsRepository]. `isEnabled` is the single question widgets ask;
/// the extra fields let a settings screen explain *why* a feature is on/off.
@immutable
class FeatureFlagsSnapshot {
  const FeatureFlagsSnapshot({
    required this.enabled,
    required this.localOverrides,
    required this.grants,
    required this.authenticated,
    this.shouldAskRussianContent = false,
  });

  /// The empty starting point: guest tier on, nothing granted, signed out.
  factory FeatureFlagsSnapshot.initial() => FeatureFlagsSnapshot.resolve(
    localOverrides: const {},
    grants: const {},
    authenticated: false,
  );

  /// Resolve the whole catalog: a feature is on when its tier is satisfied
  /// (guest → always, authenticated → signed in, premium → signed in *and*
  /// granted) **and** the local toggle for it is not turned off.
  factory FeatureFlagsSnapshot.resolve({
    required Map<String, bool> localOverrides,
    required Set<String> grants,
    required bool authenticated,
    bool askRussianContent = false,
  }) {
    final resolved = <AppFeature, bool>{};
    for (final f in AppFeature.values) {
      final tierOk = switch (f.access) {
        FeatureAccess.guest => true,
        FeatureAccess.authenticated => authenticated,
        FeatureAccess.premium => authenticated && grants.contains(f.key),
      };
      final localOk = localOverrides[f.key] ?? true;
      resolved[f] = tierOk && localOk;
    }
    return FeatureFlagsSnapshot(
      enabled: Map.unmodifiable(resolved),
      localOverrides: Map.unmodifiable(localOverrides),
      grants: Set.unmodifiable(grants),
      authenticated: authenticated,
      shouldAskRussianContent: askRussianContent,
    );
  }

  /// The final on/off decision per feature.
  final Map<AppFeature, bool> enabled;

  /// The user's local toggles (`key` → enabled); absent = default on.
  final Map<String, bool> localOverrides;

  /// Premium feature keys the backend granted to the signed-in user.
  final Set<String> grants;

  /// Whether a session is currently active.
  final bool authenticated;

  /// Whether the user still has to answer the Russian-content question — set
  /// while no decision is stored *and* the device language is not Russian.
  /// `RussianContentPrompt` shows the dialog while this is `true`.
  final bool shouldAskRussianContent;

  /// Whether [feature] is available to the user right now.
  bool isEnabled(AppFeature feature) => enabled[feature] ?? false;

  /// Whether [feature] is available **for a question of [categoryId]**.
  ///
  /// The premium gate is a property of the question, not of the screen: in the
  /// free categories (25/26/28) the content features are open to everybody, so
  /// a question from a paid category sitting in a personal list still opens and
  /// is answerable — only its explanation stays locked. Ask any content widget
  /// this instead of [isEnabled].
  ///
  /// Only the *premium grant* is waived; the tier below it (a feature needing a
  /// signed-in user) and the user's own local toggle still apply, and features
  /// marked [AppFeature.freeInFreeCategories] `= false` (the live AI chat) are
  /// never opened this way.
  bool isEnabledForCategory(AppFeature feature, String? categoryId) {
    if (isEnabled(feature)) return true;
    if (feature.access != FeatureAccess.premium) return false;
    if (!feature.freeInFreeCategories || !isFreeCategory(categoryId)) {
      return false;
    }
    return localEnabled(feature);
  }

  /// Whether [feature] is **locked behind the pass** for a question of
  /// [categoryId]: a premium feature the user has not turned off locally,
  /// which [isEnabledForCategory] would open with a grant (or a session and a
  /// grant — a guest is locked too, and the paywall tells them to sign in).
  ///
  /// Locked is not «off»: a locked tab stays on screen with a preview and the
  /// offer, a switched-off one disappears. That is why the two are separate
  /// questions.
  bool isLockedForCategory(AppFeature feature, String? categoryId) {
    if (feature.access != FeatureAccess.premium) return false;
    if (!localEnabled(feature)) return false;
    return !isEnabledForCategory(feature, categoryId);
  }

  /// The user's local toggle for [feature] (defaults to on).
  bool localEnabled(AppFeature feature) => localOverrides[feature.key] ?? true;

  /// Convenience mirror of the standalone Russian-content option.
  bool get russianContent => isEnabled(AppFeature.russianContent);
}
