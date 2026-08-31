import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:routemaster/routemaster.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/responsive.dart';
import '../domain/law_document.dart';
import '../zakon.dart';

/// Ширина выдвижной панели закона: колонка комфортного чтения, но не больше
/// девяти десятых окна (узкое окно браузера).
const double _kPanelMaxWidth = 560;

/// Открывает закон по ссылке [path] (`zakon?paragraph=…&chlan=…&chapter=…`,
/// в том числе относительной — как её понимает routemaster). Ссылка
/// `pravilnik?…` того же вида открывает правилник о саобраћајној
/// сигнализацији — документ определяется самим адресом, см. [documentOfPath].
///
/// На широком экране закон больше не занимает отдельное окно: он выезжает
/// боковой панелью поверх текущего экрана, так что вопрос (конспект, попап с
/// определением) остаётся на виду и никуда не уходит из стека. На телефоне
/// панель шириной в экран ничем не отличалась бы от страницы, поэтому там
/// по-прежнему открывается маршрут.
Future<void> openZakon(
  BuildContext context,
  String path, {
  Map<String, String>? queryParameters,
}) {
  final params = {
    ...Uri.parse(path).queryParameters,
    ...?queryParameters,
  };
  final document = documentOfPath(path);
  // Логируется здесь, а не на экране: на широком экране панель не роут и
  // события `$screen` не поднимает, а сюда сходятся оба варианта открытия.
  analytics.logZakonOpened(
    chlan: params['chlan'],
    paragraph: params['paragraph'],
    chapter: params['chapter'],
    document: document.analyticsName,
  );
  if (!context.isExpandedScreen) {
    Routemaster.of(context).push(path, queryParameters: queryParameters);
    return Future<void>.value();
  }
  return showZakonPanel(
    context,
    document: document,
    paragraph: params['paragraph'],
    chlan: params['chlan'],
    chapter: params['chapter'],
  );
}

/// Документ, на который указывает ссылка [path]: `pravilnik?…` (и
/// `/pravilnik`) — правилник, всё остальное — закон. Ссылки приходят из
/// текстов (объяснение к вопросу, конспект, словарь), поэтому разбирается
/// только первый сегмент пути.
LawDocument documentOfPath(String path) {
  final segments = Uri.parse(path).pathSegments.where((s) => s.isNotEmpty);
  return segments.isNotEmpty && segments.first == 'pravilnik'
      ? LawDocument.pravilnik
      : LawDocument.zakonOBezbednosti;
}

/// Сама панель: выезжает справа, закрывается крестиком или тапом по затемнению.
Future<void> showZakonPanel(
  BuildContext context, {
  LawDocument document = LawDocument.zakonOBezbednosti,
  String? paragraph,
  String? chlan,
  String? chapter,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      final width = math.min(
        MediaQuery.sizeOf(context).width * 0.9,
        _kPanelMaxWidth,
      );
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: ClipRRect(
            borderRadius: const BorderRadiusDirectional.horizontal(
              start: Radius.circular(20),
            ).resolve(Directionality.of(context)),
            child: Zakon(
              document: document,
              paragraph: paragraph,
              chlan: chlan,
              chapter: chapter,
              asPanel: true,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}
