// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../auth/data/auth_repository.dart' as _i880;
import '../auth/data/graphql_client.dart' as _i483;
import '../auth/data/graphql_subscription_client.dart' as _i966;
import '../auth/data/token_storage.dart' as _i25;
import '../auth/state_management/auth/auth_bloc.dart' as _i388;
import '../auth/state_management/confirm_code/confirm_code_bloc.dart' as _i892;
import '../auth/state_management/firebase_login/firebase_login_bloc.dart'
    as _i531;
import '../auth/state_management/login/login_bloc.dart' as _i10;
import '../auth/state_management/register/register_bloc.dart' as _i830;
import '../auth/state_management/reset_password/reset_password_bloc.dart'
    as _i940;
import '../feature_flags/data/feature_flags_repository.dart' as _i389;
import '../feature_flags/domain/app_feature.dart' as _i392;
import '../groups/data/groups_repository.dart' as _i685;
import '../groups/state_management/group_bloc.dart' as _i1064;
import '../groups/state_management/group_feed_bloc.dart' as _i481;
import '../groups/state_management/groups_bloc.dart' as _i1032;
import '../konspekt/data/konspekt_repository.dart' as _i491;
import '../konspekt/state_management/konspekt_bloc.dart' as _i198;
import '../konspekt/state_management/konspekt_catalog_bloc.dart' as _i187;
import '../notifications/data/notification_permissions.dart' as _i426;
import '../notifications/data/push_token_service.dart' as _i875;
import '../notifications/state_management/notifications_bloc.dart' as _i618;
import '../profile/data/profile_repository.dart' as _i311;
import '../profile/state_management/display_name_bloc.dart' as _i957;
import '../public_comments/data/public_comments_repository.dart' as _i989;
import '../public_comments/state_management/comment_count_bloc.dart' as _i955;
import '../public_comments/state_management/comments_bloc.dart' as _i405;
import '../public_comments/state_management/moderation_bloc.dart' as _i515;
import '../question_feedback/domain/question_feedback_source.dart' as _i7;
import '../question_feedback/state_management/question_feedback_bloc.dart'
    as _i751;
import '../question_lists/data/question_lists_repository.dart' as _i206;
import '../question_lists/state_management/question_lists_bloc.dart' as _i1000;
import '../support_chat/data/support_chat_repository.dart' as _i968;
import '../support_chat/models/support_chat.dart' as _i163;
import '../support_chat/state_management/support_chat_bloc.dart' as _i639;
import '../support_chat/state_management/support_image_bloc.dart' as _i681;
import '../support_chat/state_management/support_threads_bloc.dart' as _i252;
import '../test/data/quiz_preferences_repository.dart' as _i442;
import '../test/practice/state_management/practice_page_bloc.dart' as _i790;
import '../test/quest/comment/data/comment_repository.dart' as _i359;
import '../test/quest/comment/editor/state_management/comment_editor_bloc.dart'
    as _i658;
import '../test/quest/comment/state_management/comment_bloc.dart' as _i213;
import '../test/quest/question_features/ask_ai/data/question_explanation_repository.dart'
    as _i1026;
import '../test/quest/question_features/ask_ai/state_management/ask_ai_bloc.dart'
    as _i1003;
import '../test/quest/question_features/data/question_analytics_repository.dart'
    as _i1002;
import '../test/quest/question_features/data/question_difficulty_repository.dart'
    as _i147;
import '../test/quest/question_features/state_management/question_analytics_bloc.dart'
    as _i480;
import '../test/quest/question_features/state_management/question_features_bloc.dart'
    as _i269;
import '../test/quest/question_features/state_management/question_konspekt_bloc.dart'
    as _i192;
import '../test/state_management/start_test_bloc.dart' as _i31;
import 'deep_links/deep_link_service.dart' as _i547;
import 'di.dart' as _i913;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i25.TokenStorage>(() => _i25.TokenStorage());
    gh.lazySingleton<_i547.DeepLinkService>(() => _i547.DeepLinkService());
    gh.lazySingleton<_i389.FeatureFlagsRepository>(
      () => registerModule.featureFlagsRepository(),
    );
    gh.lazySingleton<_i426.NotificationPermissions>(
      () => const _i426.NotificationPermissions(),
    );
    gh.lazySingleton<_i442.QuizPreferencesRepository>(
      () => _i442.QuizPreferencesRepository(),
    );
    gh.lazySingleton<_i1002.QuestionAnalyticsRepository>(
      () => _i1002.QuestionAnalyticsRepository(),
    );
    gh.factory<_i790.PracticePageBloc>(
      () => _i790.PracticePageBloc(gh<_i442.QuizPreferencesRepository>()),
    );
    gh.factory<_i31.StartTestBloc>(
      () => _i31.StartTestBloc(gh<_i442.QuizPreferencesRepository>()),
    );
    gh.lazySingleton<_i483.GraphqlClient>(
      () => registerModule.graphqlClient(gh<_i25.TokenStorage>()),
    );
    gh.lazySingleton<_i880.AuthRepository>(
      () => _i880.AuthRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i25.TokenStorage>(),
      ),
      dispose: (i) => i.dispose(),
    );
    gh.factoryParam<_i892.ConfirmCodeBloc, String, dynamic>(
      (email, _) => _i892.ConfirmCodeBloc(gh<_i880.AuthRepository>(), email),
    );
    gh.factoryParam<_i269.QuestionFeaturesBloc, _i392.AppFeature?, dynamic>(
      (initial, _) => _i269.QuestionFeaturesBloc(
        gh<_i442.QuizPreferencesRepository>(),
        initial,
      ),
    );
    gh.factory<_i531.FirebaseLoginBloc>(
      () => _i531.FirebaseLoginBloc(gh<_i880.AuthRepository>()),
    );
    gh.factory<_i10.LoginBloc>(
      () => _i10.LoginBloc(gh<_i880.AuthRepository>()),
    );
    gh.factory<_i830.RegisterBloc>(
      () => _i830.RegisterBloc(gh<_i880.AuthRepository>()),
    );
    gh.factory<_i940.ResetPasswordBloc>(
      () => _i940.ResetPasswordBloc(gh<_i880.AuthRepository>()),
    );
    gh.lazySingleton<_i875.PushTokenService>(
      () => _i875.PushTokenService(gh<_i880.AuthRepository>()),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i966.GraphqlSubscriptionClient>(
      () => registerModule.graphqlSubscriptionClient(
        gh<_i483.GraphqlClient>(),
        gh<_i25.TokenStorage>(),
      ),
    );
    gh.lazySingleton<_i491.KonspektRepository>(
      () => _i491.KonspektRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i311.ProfileRepository>(
      () => _i311.ProfileRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i989.PublicCommentsRepository>(
      () => _i989.PublicCommentsRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i206.QuestionListsRepository>(
      () => _i206.QuestionListsRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i147.QuestionDifficultyRepository>(
      () => _i147.QuestionDifficultyRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i388.AuthBloc>(
      () => _i388.AuthBloc(
        gh<_i880.AuthRepository>(),
        gh<_i966.GraphqlSubscriptionClient>(),
      ),
    );
    gh.factory<_i618.NotificationsBloc>(
      () => _i618.NotificationsBloc(
        gh<_i880.AuthRepository>(),
        gh<_i388.AuthBloc>(),
        gh<_i426.NotificationPermissions>(),
      ),
    );
    gh.factoryParam<_i480.QuestionAnalyticsBloc, int, dynamic>(
      (questionId, _) => _i480.QuestionAnalyticsBloc(
        gh<_i1002.QuestionAnalyticsRepository>(),
        gh<_i147.QuestionDifficultyRepository>(),
        gh<_i388.AuthBloc>(),
        questionId,
      ),
    );
    gh.factory<_i187.KonspektCatalogBloc>(
      () => _i187.KonspektCatalogBloc(gh<_i491.KonspektRepository>()),
    );
    gh.factoryParam<_i198.KonspektBloc, String, String?>(
      (categoryId, initialSection) => _i198.KonspektBloc(
        gh<_i491.KonspektRepository>(),
        categoryId,
        initialSection,
      ),
    );
    gh.lazySingleton<_i359.CommentRepository>(
      () => _i359.CommentRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i389.FeatureFlagsRepository>(),
      ),
    );
    gh.lazySingleton<_i1026.QuestionExplanationRepository>(
      () => _i1026.QuestionExplanationRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i389.FeatureFlagsRepository>(),
      ),
    );
    gh.factoryParam<_i192.QuestionKonspektBloc, int, String>(
      (questionId, categoryId) => _i192.QuestionKonspektBloc(
        gh<_i491.KonspektRepository>(),
        questionId,
        categoryId,
      ),
    );
    gh.factory<_i515.ModerationBloc>(
      () => _i515.ModerationBloc(gh<_i989.PublicCommentsRepository>()),
    );
    gh.lazySingleton<_i685.GroupsRepository>(
      () => _i685.GroupsRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i966.GraphqlSubscriptionClient>(),
      ),
    );
    gh.lazySingleton<_i968.SupportChatRepository>(
      () => _i968.SupportChatRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i966.GraphqlSubscriptionClient>(),
      ),
    );
    gh.factoryParam<_i955.CommentCountBloc, int, dynamic>(
      (questionId, _) => _i955.CommentCountBloc(
        gh<_i989.PublicCommentsRepository>(),
        gh<_i388.AuthBloc>(),
        questionId,
      ),
    );
    gh.factory<_i252.SupportThreadsBloc>(
      () => _i252.SupportThreadsBloc(gh<_i968.SupportChatRepository>()),
    );
    gh.factoryParam<_i639.SupportChatBloc, String?, dynamic>(
      (threadId, _) => _i639.SupportChatBloc(
        gh<_i968.SupportChatRepository>(),
        gh<_i426.NotificationPermissions>(),
        gh<_i880.AuthRepository>(),
        threadId,
      ),
    );
    gh.factoryParam<_i681.SupportImageBloc, _i163.SupportAttachment, dynamic>(
      (attachment, _) =>
          _i681.SupportImageBloc(gh<_i968.SupportChatRepository>(), attachment),
    );
    gh.factory<_i957.DisplayNameBloc>(
      () => _i957.DisplayNameBloc(gh<_i311.ProfileRepository>()),
    );
    gh.factoryParam<_i658.CommentEditorBloc, int, dynamic>(
      (questionId, _) =>
          _i658.CommentEditorBloc(gh<_i359.CommentRepository>(), questionId),
    );
    gh.factoryParam<_i213.CommentBloc, int, dynamic>(
      (questionId, _) =>
          _i213.CommentBloc(gh<_i359.CommentRepository>(), questionId),
    );
    gh.factoryParam<_i1064.GroupBloc, String, dynamic>(
      (groupId, _) => _i1064.GroupBloc(
        gh<_i685.GroupsRepository>(),
        gh<_i389.FeatureFlagsRepository>(),
        groupId,
      ),
    );
    gh.factory<_i1000.QuestionListsBloc>(
      () => _i1000.QuestionListsBloc(
        gh<_i206.QuestionListsRepository>(),
        gh<_i388.AuthBloc>(),
      ),
    );
    gh.factoryParam<_i405.CommentsBloc, int, String?>(
      (questionId, threadId) => _i405.CommentsBloc(
        gh<_i989.PublicCommentsRepository>(),
        gh<_i311.ProfileRepository>(),
        gh<_i388.AuthBloc>(),
        gh<_i880.AuthRepository>(),
        gh<_i426.NotificationPermissions>(),
        questionId,
        threadId,
      ),
    );
    gh.factory<_i1032.GroupsBloc>(
      () => _i1032.GroupsBloc(
        gh<_i685.GroupsRepository>(),
        gh<_i311.ProfileRepository>(),
        gh<_i388.AuthBloc>(),
        gh<_i389.FeatureFlagsRepository>(),
      ),
    );
    gh.factoryParam<_i1003.AskAiBloc, int, dynamic>(
      (questionId, _) => _i1003.AskAiBloc(
        gh<_i1026.QuestionExplanationRepository>(),
        questionId,
      ),
    );
    gh.factoryParam<_i481.GroupFeedBloc, String, dynamic>(
      (groupId, _) =>
          _i481.GroupFeedBloc(gh<_i685.GroupsRepository>(), groupId),
    );
    gh.factoryParam<
      _i751.QuestionFeedbackBloc,
      int,
      _i7.QuestionFeedbackSource
    >(
      (questionId, source) => _i751.QuestionFeedbackBloc(
        gh<_i968.SupportChatRepository>(),
        gh<_i426.NotificationPermissions>(),
        gh<_i880.AuthRepository>(),
        gh<_i388.AuthBloc>(),
        questionId,
        source,
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i913.RegisterModule {}
