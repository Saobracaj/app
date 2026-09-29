import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the home-screen cards remember on this device: the exam date, the
/// daily goal and today's answer to the question of the day.
///
/// All of it is local by nature — a goal is a habit of one person on one
/// device, and the date is only used to count days — so it lives in shared
/// preferences and never goes to the backend.
@lazySingleton
class HomePreferencesRepository {
  static const _examDateKey = 'home.exam_date';
  static const _dailyGoalKey = 'home.daily_goal';
  static const _dailyQuestionKey = 'home.daily_question';

  /// The daily goal a fresh install starts with, in questions.
  static const defaultDailyGoal = 30;

  /// The goals the user can pick from on the activity card.
  static const dailyGoalOptions = [10, 20, 30, 50, 100];

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// The exam date the user entered, or `null` when none is set. Only the
  /// calendar day matters; the stored value is midnight local time.
  Future<DateTime?> examDate() async {
    final raw = (await _store).getString(_examDateKey);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Stores [date] (`null` removes it).
  Future<void> setExamDate(DateTime? date) async {
    final prefs = await _store;
    if (date == null) {
      await prefs.remove(_examDateKey);
      return;
    }
    final day = DateTime(date.year, date.month, date.day);
    await prefs.setString(_examDateKey, day.toIso8601String());
  }

  /// How many questions a day the user aims for.
  Future<int> dailyGoal() async =>
      (await _store).getInt(_dailyGoalKey) ?? defaultDailyGoal;

  Future<void> setDailyGoal(int goal) async =>
      (await _store).setInt(_dailyGoalKey, goal);

  /// The stored answer to the question of the day, or `null` when the user
  /// has not answered one yet (or the stored one is from another day).
  Future<DailyQuestionAnswer?> dailyQuestionAnswer() async {
    final raw = (await _store).getString(_dailyQuestionKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DailyQuestionAnswer(
        day: map['day'] as String,
        questionId: (map['id'] as num).toInt(),
        selected: [for (final i in map['selected'] as List) (i as num).toInt()],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setDailyQuestionAnswer(DailyQuestionAnswer answer) async =>
      (await _store).setString(
        _dailyQuestionKey,
        jsonEncode({
          'day': answer.day,
          'id': answer.questionId,
          'selected': answer.selected,
        }),
      );
}

/// Today's checked answer to the question of the day: which question it was,
/// which day (`yyyy-MM-dd`) and the option indices the user picked.
class DailyQuestionAnswer {
  const DailyQuestionAnswer({
    required this.day,
    required this.questionId,
    required this.selected,
  });

  final String day;
  final int questionId;
  final List<int> selected;
}
