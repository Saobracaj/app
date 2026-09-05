import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_state.dart';

/// Флаги гостя, но с выключенными локальными тумблерами вкладок вопроса.
///
/// Обсуждение читает и гость (тир guest), а запертые премиум-вкладки
/// (объяснение, конспект, анализ, AI) остаются на экране с превью и
/// предложением пропуска — поэтому вкладки под вопросом появляются в любом
/// тесте экрана вопроса, а им нужен весь стек (getIt, блоки вкладок, чат).
/// Тестам, чей предмет не вкладки, проще выключить их теми же локальными
/// тумблерами, которые доступны и настоящему пользователю на экране
/// «Функции»: выключенное — не заперто, вкладки нет.
class GuestFlagsWithoutDiscussionBloc extends FeatureFlagsBloc {
  GuestFlagsWithoutDiscussionBloc()
    : super(
        FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  @override
  FeatureFlagsState get state => FeatureFlagsState(
    snapshot: FeatureFlagsSnapshot.resolve(
      localOverrides: {
        AppFeature.publicQuestionComments.key: false,
        AppFeature.questionComments.key: false,
        AppFeature.categorySummaries.key: false,
        AppFeature.questionAnalysis.key: false,
        AppFeature.askAi.key: false,
        AppFeature.russianContent.key: false,
      },
      grants: const {},
      authenticated: false,
    ),
  );
}
