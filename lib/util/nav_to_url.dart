import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:url_launcher/url_launcher.dart';

void navigateToUri(BuildContext context, Uri uri) {
  if (uri.host.toLowerCase() == 'owncup.eu') {
    Routemaster.of(context).push(uri.path, queryParameters: uri.queryParameters);
  } else {
    launchUrl(uri);
  }
}