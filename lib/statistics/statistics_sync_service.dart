import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../auth/data/graphql_client.dart';
import '../auth/data/token_storage.dart';
import '../db/db.dart';
import 'phantom_subcategory.dart';

/// Two-way synchronisation of the locally-stored statistics (answer log,
/// subcategory results, practice/mock-exam results) with the `saobracaj_backend`
/// GraphQL API.
///
/// Every local record carries a stable client-generated `uuid`. A sync uploads
/// all local records (the server ignores ones it already has, matched by uuid)
/// and receives back the full merged set, from which any record the device is
/// missing is inserted locally. This makes sync:
///   * **idempotent** — running it repeatedly is harmless;
///   * **order-independent** — it works whether the user had local data before
///     logging in (that data is uploaded on the first authenticated sync) or the
///     server already had data from another device (it is pulled down here).
///
/// Sync only runs while the user is authenticated; when signed out it is a no-op,
/// and any error is swallowed (statistics are best-effort, never blocking).
class StatisticsSyncService {
  StatisticsSyncService(this._db, this._client, this._storage);

  final AppDatabase _db;
  final GraphqlClient _client;
  final TokenStorage _storage;

  bool _running = false;
  // Set when a sync is requested while one is already in flight, so we run once
  // more afterwards to pick up records added in the meantime.
  bool _pending = false;

  // Bumped by [onLoggedOut]. A sync carries the counter it started with, so a
  // response that arrives after the session ended cannot merge the previous
  // account's records back into the freshly-cleared database.
  int _session = 0;

  final _synced = StreamController<void>.broadcast();

  /// Fires after every completed sync that may have pulled new records into the
  /// local DB, and after [onLoggedOut] emptied it — listeners holding stats in
  /// memory (e.g. `AllQuestionsBloc`) re-read on it, so the numbers appear right
  /// after login instead of after the next finished test, and disappear right
  /// after logout.
  Stream<void> get synced => _synced.stream;

  static const _mutation = r'''
    mutation SyncStatistics($input: StatisticsInput!) {
      syncStatistics(input: $input) {
        answers { id questionId answeredAt isWrong }
        subcategories { id subcategory rightAnswers allAnswers occurredAt }
        practices { id points occurredAt mistakes durationSeconds wrongAnswers }
      }
    }''';

  /// Run a sync now if the user is signed in. Safe to call from anywhere
  /// (fire-and-forget); never throws.
  Future<void> sync() async {
    // Read before the first await, so a logout happening while this sync is
    // under way is always seen as a session change.
    final session = _session;
    final token = await _storage.accessToken;
    if (token == null || token.isEmpty) return; // signed out — nothing to do.

    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        await _syncOnce(session);
      } while (_pending && session == _session);
      _synced.add(null);
    } catch (e) {
      debugPrint('Statistics sync failed: $e');
    } finally {
      _running = false;
    }
  }

  /// Drop the local statistics when the session ends: they belong to the
  /// account that produced them and have already been uploaded (a sync runs
  /// after every finished test, and once more just before an explicit logout),
  /// so logging back in pulls them down again. Keeping them would fold this
  /// user's numbers into whichever account signs in next on this device.
  ///
  /// [keepLocalRecords] is the account-deletion case: the server copy no
  /// longer exists, so the local records are the only ones and stay as the
  /// guest's history when the user asked for that. The in-flight sync is still
  /// invalidated — its session is over.
  Future<void> onLoggedOut({bool keepLocalRecords = false}) async {
    _session++;
    _pending = false;
    if (!keepLocalRecords) {
      await _db.clearStatistics();
    }
    _synced.add(null);
  }

  Future<void> _syncOnce(int session) async {
    final answers = await _db.getAllAnswers();
    final subcategories = await _db.getAllSubcategoryRecords();
    final practices = await _db.getPracticeRecords();

    final input = <String, dynamic>{
      'answers': [
        for (final a in answers)
          if (a.uuid != null)
            {
              'id': a.uuid,
              'questionId': a.questionId,
              'answeredAt': a.date.toUtc().toIso8601String(),
              'isWrong': a.isWrong,
            },
      ],
      'subcategories': [
        for (final s in subcategories)
          if (s.uuid != null && !isPhantomSubcategory(s.subcategory))
            {
              'id': s.uuid,
              'subcategory': s.subcategory,
              'rightAnswers': s.rightAnswers,
              'allAnswers': s.allAnswers,
              // Null for rows written before schema v6 — the server keeps them
              // untimed rather than pretending they happened at sync time.
              'occurredAt': s.occurredAt?.toUtc().toIso8601String(),
            },
      ],
      'practices': [
        for (final p in practices)
          if (p.uuid != null)
            {
              'id': p.uuid,
              'points': p.points,
              'occurredAt': p.time.toUtc().toIso8601String(),
              'mistakes': p.mistakes,
              'durationSeconds': p.durationSeconds,
              'wrongAnswers': p.wrongAnswers ?? const <int>[],
            },
      ],
    };

    final data = await _client.run(
      _mutation,
      variables: {'input': input},
      authenticated: true,
    );

    // The user signed out while the request was in flight: this payload is the
    // previous account's, and the local database has just been cleared for it.
    if (session != _session) return;

    final result = data['syncStatistics'];
    if (result is Map<String, dynamic>) {
      await _mergeIntoLocal(result);
    }
  }

  /// Insert any server records the device does not have yet, matched by uuid.
  Future<void> _mergeIntoLocal(Map<String, dynamic> result) async {
    final knownAnswers = await _db.answerUuids();
    for (final raw in (result['answers'] as List? ?? const [])) {
      final a = raw as Map<String, dynamic>;
      final id = a['id'] as String;
      if (knownAnswers.contains(id)) continue;
      await _db.insertAnswer(
        AnswerRecordsCompanion.insert(
          questionId: (a['questionId'] as num).toInt(),
          date: DateTime.parse(a['answeredAt'] as String).toLocal(),
          isWrong: a['isWrong'] as bool,
          uuid: Value(id),
        ),
      );
    }

    final knownSubs = await _db.subcategoryUuids();
    for (final raw in (result['subcategories'] as List? ?? const [])) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'] as String;
      if (knownSubs.contains(id)) continue;
      // A phantom block: older builds recorded block-less runs under the
      // literal "null" (see the v7 migration in `AppDatabase`). A server that
      // still holds such rows must not plant them back into a cleaned device.
      if (isPhantomSubcategory(s['subcategory'])) continue;
      final occurredAt = s['occurredAt'] as String?;
      await _db.insertSubCategory(
        SubCategoryRecordsCompanion.insert(
          subcategory: s['subcategory'] as String,
          rightAnswers: (s['rightAnswers'] as num).toInt(),
          allAnswers: (s['allAnswers'] as num).toInt(),
          // Passed explicitly (even when null) so the column's clientDefault
          // does not stamp a downloaded record with the time of the download.
          occurredAt: Value(
            occurredAt == null ? null : DateTime.parse(occurredAt).toLocal(),
          ),
          uuid: Value(id),
        ),
      );
    }

    final knownPractices = await _db.practiceUuids();
    for (final raw in (result['practices'] as List? ?? const [])) {
      final p = raw as Map<String, dynamic>;
      final id = p['id'] as String;
      if (knownPractices.contains(id)) continue;
      await _db.insertPractice(
        PracticeRecordsCompanion.insert(
          points: (p['points'] as num).toInt(),
          time: DateTime.parse(p['occurredAt'] as String).toLocal(),
          mistakes: (p['mistakes'] as num).toInt(),
          durationSeconds: (p['durationSeconds'] as num).toInt(),
          wrongAnswers: Value([
            for (final w in (p['wrongAnswers'] as List? ?? const []))
              (w as num).toInt(),
          ]),
          uuid: Value(id),
        ),
      );
    }
  }
}
