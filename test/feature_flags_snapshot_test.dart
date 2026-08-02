import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';

void main() {
  group('FeatureFlagsSnapshot.resolve', () {
    test('guest sees only the guest tier', () {
      final s = FeatureFlagsSnapshot.resolve(
        localOverrides: const {},
        grants: const {},
        authenticated: false,
      );
      expect(s.isEnabled(AppFeature.questionSearch), isTrue); // guest
      expect(s.isEnabled(AppFeature.groups), isFalse); // authenticated
      expect(s.isEnabled(AppFeature.askAi), isFalse); // premium
    });

    test('authenticated unlocks the authenticated tier but not premium', () {
      final s = FeatureFlagsSnapshot.resolve(
        localOverrides: const {},
        grants: const {},
        authenticated: true,
      );
      expect(s.isEnabled(AppFeature.groups), isTrue);
      expect(s.isEnabled(AppFeature.askAi), isFalse);
    });

    test('a premium grant unlocks that feature only when signed in', () {
      final grants = {AppFeature.askAi.key};
      expect(
        FeatureFlagsSnapshot.resolve(
          localOverrides: const {},
          grants: grants,
          authenticated: true,
        ).isEnabled(AppFeature.askAi),
        isTrue,
      );
      // Same grant is worthless without a session.
      expect(
        FeatureFlagsSnapshot.resolve(
          localOverrides: const {},
          grants: grants,
          authenticated: false,
        ).isEnabled(AppFeature.askAi),
        isFalse,
      );
    });

    test('a local off toggle wins over a satisfied tier', () {
      final s = FeatureFlagsSnapshot.resolve(
        localOverrides: {AppFeature.questionSearch.key: false},
        grants: const {},
        authenticated: false,
      );
      expect(s.isEnabled(AppFeature.questionSearch), isFalse);
      expect(s.localEnabled(AppFeature.questionSearch), isFalse);
    });

    test('russianContent mirrors the russian_content premium grant', () {
      final off = FeatureFlagsSnapshot.resolve(
        localOverrides: const {},
        grants: const {},
        authenticated: true,
      );
      expect(off.russianContent, isFalse);

      final on = FeatureFlagsSnapshot.resolve(
        localOverrides: const {},
        grants: {AppFeature.russianContent.key},
        authenticated: true,
      );
      expect(on.russianContent, isTrue);
    });
  });
}
