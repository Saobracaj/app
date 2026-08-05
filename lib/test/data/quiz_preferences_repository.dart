import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../feature_flags/domain/app_feature.dart';
import '../domain/quiz_option.dart';

/// Remembers what the user chose last time: the run options of the
/// "start a category" / exam-simulation screens ([QuizOption]) and the
/// per-question tab selected while going through questions.
///
/// The choices are purely local (they configure one device's runs and mean
/// nothing to the backend), so they live in shared preferences.
///
/// Values are cached in memory by [bootstrap], called once from `main()`:
/// reads are therefore synchronous, and a screen renders the remembered state
/// on its first frame instead of showing the defaults and flipping a frame
/// later. Writes update the cache immediately and the store in the background.
@lazySingleton
class QuizPreferencesRepository {
  static const _questionTabKey = 'quiz.question_tab';

  final Map<String, bool> _options = {};
  String? _questionTab;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Loads the persisted choices into memory. Call once from `main()` before
  /// `runApp`; until then every getter answers with the defaults.
  Future<void> bootstrap() async {
    final prefs = await _store;
    for (final option in QuizOption.values) {
      final value = prefs.getBool(option.storageKey);
      if (value != null) _options[option.storageKey] = value;
    }
    _questionTab = prefs.getString(_questionTabKey);
  }

  /// The remembered value of [option], or its default when never set.
  bool isEnabled(QuizOption option) =>
      _options[option.storageKey] ?? option.defaultValue;

  /// Remembers [option]'s new value for the next run.
  Future<void> setEnabled(QuizOption option, bool value) async {
    _options[option.storageKey] = value;
    await (await _store).setBool(option.storageKey, value);
  }

  /// The per-question tab the user last opened, or `null` when there is none
  /// (never selected, or a feature this build no longer knows). Callers still
  /// have to check the tab is currently available — it may be gated by a
  /// feature flag the user has since lost — and fall back to the first visible
  /// one if it isn't.
  AppFeature? get questionTab {
    final key = _questionTab;
    return key == null ? null : AppFeature.fromKey(key);
  }

  /// Remembers the per-question tab the user switched to.
  Future<void> setQuestionTab(AppFeature feature) async {
    _questionTab = feature.key;
    await (await _store).setString(_questionTabKey, feature.key);
  }
}
