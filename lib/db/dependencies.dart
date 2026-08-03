import '../auth/data/graphql_client.dart';
import '../auth/data/token_storage.dart';
import '../core/di.dart';
import '../feature_flags/data/feature_flags_repository.dart';
import '../session/session_sync_service.dart';
import '../statistics/statistics_sync_service.dart';
import 'answer_repository.dart';
import 'db.dart';

final db = AppDatabase();
final repository = AnswerRepository(db);

// These globals resolve the shared GraphQL client / token storage from `getIt`,
// so every request goes through the same token-refresh path (one in-flight
// refresh, one `sessionExpired` signal wired to `AuthRepository`). They are lazy
// — `main()` calls `configureDependencies()` before anything touches them.
GraphqlClient get _client => getIt<GraphqlClient>();
TokenStorage get _syncTokenStorage => getIt<TokenStorage>();

// Statistics sync. Triggered automatically after login/startup (AuthBloc) and
// after each finished test.
final StatisticsSyncService statisticsSync = StatisticsSyncService(
  db,
  _client,
  _syncTokenStorage,
);

// Cross-device active-session sync: mirrors the current route across the user's
// devices. Pushed on navigation (SessionRouteObserver) and pulled on
// login/startup to offer "continue where you left off" (SessionResumeGate).
final SessionSyncService sessionSync = SessionSyncService(
  _client,
  _syncTokenStorage,
);

// Feature-flag availability: local toggles (shared preferences) + premium
// grants pulled from the backend `featureFlags` query. Bootstrapped in main()
// and refreshed/cleared from AuthBloc on session changes. Widgets read it
// through FeatureFlagsBloc.
final FeatureFlagsRepository featureFlags = FeatureFlagsRepository(
  _client,
  _syncTokenStorage,
);
