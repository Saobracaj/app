import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/deep_links/deep_link_path.dart';
import '../core/navigation.dart';

/// Открывает [uri] внутри приложения, если это адрес нашего же продукта.
///
/// Ссылка на `saobracaj.gleb.at` (и её вариант со схемой `saobracaj://`) ведёт
/// на экран, который у приложения уже есть, — уводить за таким в браузер нет
/// смысла. Адрес разбирается тем же [deepLinkPathFor], что и ссылка, пришедшая
/// извне, поэтому набор поддерживаемых путей у внешнего диплинка и у ссылки,
/// нажатой внутри приложения, один и тот же.
///
/// Возвращает `false`, если по адресу нашего экрана нет (чужой домен или путь,
/// которого нет в таблице маршрутов) — такую ссылку должен открыть браузер.
bool openAppUri(BuildContext context, Uri uri) {
  final path = deepLinkPathFor(uri);
  if (path == null) return false;
  final target = Uri.parse(path);
  // «Экран поверх экрана» у routemaster существует только как зарегистрированный
  // путь. Если такой есть (закон или конспект, открытые из текста вопроса), то
  // открываем именно его — тогда «назад» возвращает туда, где нажали ссылку.
  final relative = target.path.replaceFirst(RegExp('^/'), '');
  if (relative.isNotEmpty && isRoutable(context, relative)) {
    Routemaster.of(context).push(
      relative,
      queryParameters: target.queryParameters.isEmpty
          ? null
          : target.queryParameters,
    );
    return true;
  }
  // Иначе абсолютный путь: стек строится из URL, так что экран получается ровно
  // тот, на который указывает адрес — как при переходе по диплинку извне.
  Routemaster.of(context).push(path);
  return true;
}

/// Открывает [uri]: свои ссылки — внутри приложения, остальные — в браузере.
void navigateToUri(BuildContext context, Uri uri) {
  if (openAppUri(context, uri)) return;
  launchUrl(uri);
}
