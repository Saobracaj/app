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
import '../auth/state_management/auth_cubit.dart' as _i429;
import '../auth/state_management/confirm_code/confirm_code_bloc.dart' as _i892;
import '../auth/state_management/login/login_bloc.dart' as _i10;
import '../auth/state_management/register/register_bloc.dart' as _i830;
import '../auth/state_management/reset_password/reset_password_bloc.dart'
    as _i940;
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
    gh.lazySingleton<_i483.GraphqlClient>(
      () => registerModule.graphqlClient(gh<_i25.TokenStorage>()),
    );
    gh.lazySingleton<_i880.AuthRepository>(
      () => _i880.AuthRepository(
        gh<_i483.GraphqlClient>(),
        gh<_i25.TokenStorage>(),
      ),
    );
    gh.lazySingleton<_i429.AuthCubit>(
      () => _i429.AuthCubit(gh<_i880.AuthRepository>()),
    );
    gh.factoryParam<_i892.ConfirmCodeBloc, String, dynamic>(
      (email, _) => _i892.ConfirmCodeBloc(
        gh<_i880.AuthRepository>(),
        gh<_i429.AuthCubit>(),
        email,
      ),
    );
    gh.factory<_i10.LoginBloc>(
      () => _i10.LoginBloc(gh<_i880.AuthRepository>(), gh<_i429.AuthCubit>()),
    );
    gh.factory<_i830.RegisterBloc>(
      () =>
          _i830.RegisterBloc(gh<_i880.AuthRepository>(), gh<_i429.AuthCubit>()),
    );
    gh.factory<_i940.ResetPasswordBloc>(
      () => _i940.ResetPasswordBloc(
        gh<_i880.AuthRepository>(),
        gh<_i429.AuthCubit>(),
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i913.RegisterModule {}
