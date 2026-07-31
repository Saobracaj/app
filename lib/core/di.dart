import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../auth/data/graphql_client.dart';
import '../auth/data/token_storage.dart';
import 'di.config.dart';

/// Global service locator. Obtain any registered dependency with `getIt<T>()`.
/// Never hand-construct a Bloc or repository in widget code — resolve it here.
final getIt = GetIt.instance;

/// Registers every `@injectable` / `@lazySingleton` / `@module` dependency.
/// Call once from `main()` before `runApp`. The `init` extension is generated
/// into `di.config.dart` by `injectable_generator` (run codegen after changing
/// annotations).
@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
void configureDependencies() => getIt.init();

/// Third-party / hand-built dependencies that injectable can't construct from a
/// plain annotated constructor.
@module
abstract class RegisterModule {
  @lazySingleton
  GraphqlClient graphqlClient(TokenStorage storage) => GraphqlClient(storage);
}
