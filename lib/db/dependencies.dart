import '../auth/data/graphql_client.dart';
import '../auth/data/token_storage.dart';
import '../statistics/statistics_sync_service.dart';
import 'answer_repository.dart';
import 'db.dart';

final db = AppDatabase();
final repository = AnswerRepository(db);

// Statistics sync uses its own TokenStorage (shared_preferences-backed, so it
// sees the same tokens the auth layer stores) and a GraphQL client. Triggered
// automatically after login/startup (AuthCubit) and after each finished test.
final TokenStorage _syncTokenStorage = TokenStorage();
final StatisticsSyncService statisticsSync = StatisticsSyncService(
  db,
  GraphqlClient(_syncTokenStorage),
  _syncTokenStorage,
);
