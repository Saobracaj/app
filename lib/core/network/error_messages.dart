import 'package:easy_localization/easy_localization.dart';

import '../../auth/data/graphql_client.dart';
import '../../generated/locale_keys.g.dart';

/// Turn a caught error into the text a user should see.
///
/// * a transport failure ([GraphqlException.network]) becomes the localized
///   "no network" line — the client's own message is an English placeholder;
/// * any other [GraphqlException] carries the server's message, which is
///   already in the caller's language and names the rule that refused the
///   call — shown as is;
/// * anything else falls back to [fallback] (a translation key's value) or, if
///   none is given, to `toString()` so nothing is silently swallowed.
String describeError(Object error, {String? fallback}) {
  if (error is GraphqlException) {
    if (error.network) return LocaleKeys.network_noConnection.tr();
    if (error.message.isNotEmpty) return error.message;
  }
  return fallback ?? error.toString();
}

/// Whether [error] is a "never reached the server" failure — the case where the
/// UI shows "no network" and reloads on its own once the connection is back.
bool isNetworkError(Object error) =>
    error is GraphqlException && error.network;
