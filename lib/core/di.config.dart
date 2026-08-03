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
import '../auth/data/token_storage.dart' as _i25;
import '../auth/state_management/auth/auth_bloc.dart' as _i388;
import '../auth/state_management/confirm_code/confirm_code_bloc.dart' as _i892;
import '../auth/state_management/firebase_login/firebase_login_bloc.dart'
    as _i531;
import '../auth/state_management/login/login_bloc.dart' as _i10;
import '../auth/state_management/register/register_bloc.dart' as _i830;
import '../auth/state_management/reset_password/reset_password_bloc.dart'
    as _i940;
import '../notifications/data/notification_permissions.dart' as _i426;
import '../notifications/data/push_token_service.dart' as _i875;
import '../notifications/state_management/notifications_bloc.dart' as _i618;
import '../profile/data/profile_repository.dart' as _i311;
import '../profile/state_management/display_name_bloc.dart' as _i957;
import '../public_comments/data/public_comments_repository.dart' as _i989;
import '../public_comments/state_management/comment_count_bloc.dart' as _i955;
import '../public_comments/state_management/comments_bloc.dart' as _i405;
import '../test/quest/comment/data/comment_repository.dart' as _i359;
import '../test/quest/comment/state_management/comment_bloc.dart' as _i213;
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
    gh.lazySingleton<_i426.NotificationPermissions>(
      () => const _i426.NotificationPermissions(),
    );
    gh.lazySingleton<_i483.GraphqlClient>(
      () => registerModule.graphqlClient(gh<_i25.TokenStorage>()),
    );
    gh.lazySingleton<_i880.AuthRepository>(
      () => _i880.AuthRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i25.TokenStorage>(),
      ),
    );
    gh.factoryParam<_i892.ConfirmCodeBloc, String, dynamic>(
      (email, _) => _i892.ConfirmCodeBloc(gh<_i880.AuthRepository>(), email),
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
    gh.lazySingleton<_i388.AuthBloc>(
      () => _i388.AuthBloc(gh<_i880.AuthRepository>()),
    );
    gh.lazySingleton<_i311.ProfileRepository>(
      () => _i311.ProfileRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i989.PublicCommentsRepository>(
      () => _i989.PublicCommentsRepository(gh<_i483.GraphqlClient>()),
    );
    gh.lazySingleton<_i359.CommentRepository>(
      () => _i359.CommentRepository(gh<_i483.GraphqlClient>()),
    );
    gh.factory<_i618.NotificationsBloc>(
      () => _i618.NotificationsBloc(
        gh<_i880.AuthRepository>(),
        gh<_i388.AuthBloc>(),
        gh<_i426.NotificationPermissions>(),
      ),
    );
    gh.factoryParam<_i955.CommentCountBloc, int, dynamic>(
      (questionId, _) => _i955.CommentCountBloc(
        gh<_i989.PublicCommentsRepository>(),
        gh<_i388.AuthBloc>(),
        questionId,
      ),
    );
    gh.factory<_i957.DisplayNameBloc>(
      () => _i957.DisplayNameBloc(gh<_i311.ProfileRepository>()),
    );
    gh.factoryParam<_i213.CommentBloc, int, dynamic>(
      (questionId, _) =>
          _i213.CommentBloc(gh<_i359.CommentRepository>(), questionId),
    );
    gh.factoryParam<_i405.CommentsBloc, int, dynamic>(
      (questionId, _) => _i405.CommentsBloc(
        gh<_i989.PublicCommentsRepository>(),
        gh<_i311.ProfileRepository>(),
        gh<_i388.AuthBloc>(),
        questionId,
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i913.RegisterModule {}
