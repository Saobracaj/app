import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/deep_links.dart';

/// A push notification as the app cares about it: what to show and where it
/// leads.
///
/// The backend (`base_rust_backend`, `FcmV1Sender`) sends the title and body in
/// the FCM `notification` block and the deep link — when there is one — as
/// `data.link`. The link takes any of the shapes the backend produces:
///   * `saobracaj://question/123?comments=1` or `saobracaj://support` — the
///     app's own scheme;
///   * `https://saobracaj.gleb.at/question/123` — the web address;
///   * `/settings` — a bare in-app path (what the test-push screen suggests),
///     which is read as an address on the app's own host.
///
/// Anything else (`https://example.com/…`) is kept as is: it is not ours to
/// open in-app, so it goes to the browser.
@immutable
class PushMessage {
  const PushMessage({this.title, this.body, this.link});

  final String? title;
  final String? body;

  /// Where the notification leads, or `null` for a purely informational one.
  final Uri? link;

  /// The parts of [message] this app uses; `null` when there is nothing to
  /// show and nowhere to go (a data-only ping, say).
  static PushMessage? fromRemote(RemoteMessage message) {
    final data = message.data;
    final title = _text(message.notification?.title) ?? _text(data['title']);
    final body = _text(message.notification?.body) ?? _text(data['body']);
    final link = parseLink(data['link']);
    if (title == null && body == null && link == null) return null;
    return PushMessage(title: title, body: body, link: link);
  }

  /// [raw] as an absolute [Uri], or `null` when it is empty or unparseable.
  ///
  /// A bare path (`/settings`) becomes an address on the app's own host, so the
  /// same routing decides where it opens as for a full link.
  @visibleForTesting
  static Uri? parseLink(Object? raw) {
    final text = _text(raw);
    if (text == null) return null;
    if (text.startsWith('/')) {
      final asUri = Uri.tryParse(text);
      if (asUri == null) return null;
      return appLink(
        asUri.path,
        asUri.hasQuery ? asUri.queryParametersAll : null,
      );
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return null;
    return uri;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is PushMessage &&
      other.title == title &&
      other.body == body &&
      other.link == link;

  @override
  int get hashCode => Object.hash(title, body, link);

  @override
  String toString() => 'PushMessage(title: $title, body: $body, link: $link)';
}
