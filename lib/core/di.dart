import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../auth/data/graphql_client.dart';
import '../auth/data/graphql_subscription_client.dart';
import '../auth/data/token_storage.dart';
import '../db/dependencies.dart' show featureFlags;
import '../feature_flags/data/feature_flags_repository.dart';
import 'analytics/analytics_event_sink.dart';
import 'app_language.dart';
import 'di.config.dart';
import 'network/network_status.dart';

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
  /// The app-wide online/offline signal. `main()` calls `start()` on it before
  /// `runApp`; the GraphQL client reports transport outcomes into it. The probe
  /// resolves the client lazily — the client itself depends on this instance.
  @lazySingleton
  NetworkStatus networkStatus() => NetworkStatus(
    probe: () => getIt<GraphqlClient>().run('query Ping { __typename }'),
  );

  @lazySingleton
  GraphqlClient graphqlClient(TokenStorage storage, NetworkStatus network) =>
      GraphqlClient(
        storage,
        languageProvider: () => appLanguageCode,
        networkStatus: network,
      );

  /// GraphQL subscriptions over the websocket endpoint. Shares the HTTP
  /// client's token handling — a subscription is authenticated with the same
  /// (freshly refreshed) access token.
  @lazySingleton
  GraphqlSubscriptionClient graphqlSubscriptionClient(
    GraphqlClient client,
    TokenStorage storage,
  ) => GraphqlSubscriptionClient(
    client,
    storage,
    languageProvider: () => appLanguageCode,
  );

  /// Второй приёмник аналитики — собственный бэкенд. Регистрируется здесь, а
  /// не аннотацией на классе: у конструктора есть именованные параметры
  /// (интервал отправки, размер пачки), которые injectable попытался бы
  /// разрешить как зависимости.
  @lazySingleton
  AnalyticsEventSink analyticsEventSink(
    GraphqlClient client,
    TokenStorage storage,
  ) => AnalyticsEventSink(client, storage);

  /// Feature availability. The repository is a global built in
  /// `lib/db/dependencies.dart` and bootstrapped in `main()` before the widget
  /// tree exists; exposing that same instance here lets Blocs depend on it like
  /// on any other repository instead of reaching for the global themselves.
  @lazySingleton
  FeatureFlagsRepository featureFlagsRepository() => featureFlags;
}
