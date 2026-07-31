import '../auth/data/graphql_client.dart';
import '../auth/data/token_storage.dart';
import '../session/session_sync_service.dart';
import '../statistics/statistics_sync_service.dart';
import 'answer_repository.dart';
import 'db.dart';

final db = AppDatabase();
final repository = AnswerRepository(db);

// Statistics sync uses its own TokenStorage (shared_preferences-backed, so it
// sees the same tokens the auth layer stores) and a GraphQL client. Triggered
// automatically after login/startup (AuthBloc) and after each finished test.
final TokenStorage _syncTokenStorage = TokenStorage();
final StatisticsSyncService statisticsSync = StatisticsSyncService(
  db,
  GraphqlClient(_syncTokenStorage),
  _syncTokenStorage,
);

// Cross-device active-session sync: mirrors the current route across the user's
// devices. Pushed on navigation (SessionRouteObserver) and pulled on
// login/startup to offer "continue where you left off" (SessionResumeGate).
final SessionSyncService sessionSync = SessionSyncService(
  GraphqlClient(_syncTokenStorage),
  _syncTokenStorage,
);
