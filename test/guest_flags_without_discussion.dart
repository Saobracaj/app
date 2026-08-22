import 'package:saobracaj/auth/data/graphql_client.dart';
import 'package:saobracaj/auth/data/token_storage.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_repository.dart';
import 'package:saobracaj/feature_flags/data/feature_flags_snapshot.dart';
import 'package:saobracaj/feature_flags/domain/app_feature.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_bloc.dart';
import 'package:saobracaj/feature_flags/state_management/feature_flags_state.dart';

/// Флаги гостя, но с выключенным локальным тумблером обсуждения вопроса.
///
/// Обсуждение читает и гость (тир guest), поэтому вкладки под вопросом
/// появляются в любом тесте экрана вопроса — а им нужен весь чат-стек
/// (getIt, ChatBloc, счётчик сообщений). Тестам, чей предмет не вкладки,
/// проще выключить обсуждение тем же локальным тумблером, который доступен
/// и настоящему пользователю на экране «Функции».
class GuestFlagsWithoutDiscussionBloc extends FeatureFlagsBloc {
  GuestFlagsWithoutDiscussionBloc()
    : super(
        FeatureFlagsRepository(GraphqlClient(TokenStorage()), TokenStorage()),
      );

  @override
  FeatureFlagsState get state => FeatureFlagsState(
    snapshot: FeatureFlagsSnapshot.resolve(
      localOverrides: {AppFeature.publicQuestionComments.key: false},
      grants: const {},
      authenticated: false,
    ),
  );
}
