import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../generated/locale_keys.g.dart';

/// Просит следующую страницу, когда список подошёл к концу — и, что важнее,
/// когда он до конца экрана вообще не дорос.
///
/// Одного [ScrollNotification] для этого мало: пока в списке нечего прокручивать,
/// событий прокрутки нет, а значит следующая страница не запрашивается никогда.
/// Список с короткой (например, почти целиком отфильтрованной) первой страницей
/// так и застывал с вечным индикатором внизу. [ScrollMetricsNotification]
/// приходит без участия пользователя — при первой же раскладке и всякий раз,
/// когда меняется размер содержимого или окна, — и закрывает этот случай.
class PaginationTrigger extends StatelessWidget {
  const PaginationTrigger({
    super.key,
    required this.enabled,
    required this.onLoadMore,
    required this.child,
  });

  /// Есть что подгружать и загрузка не идёт прямо сейчас.
  final bool enabled;

  final VoidCallback onLoadMore;

  final Widget child;

  /// За сколько пикселей до конца списка просить следующую страницу, чтобы
  /// прокрутка не останавливалась в ожидании ответа.
  static const _lookahead = 400.0;

  bool _maybeLoadMore(ScrollMetrics metrics) {
    if (enabled &&
        metrics.axis == Axis.vertical &&
        metrics.pixels > metrics.maxScrollExtent - _lookahead) {
      onLoadMore();
    }
    // Уведомление не наше — пусть идёт дальше вверх по дереву.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _maybeLoadMore(notification.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _maybeLoadMore(notification.metrics),
        child: child,
      ),
    );
  }
}

/// Подвал списка с постраничной загрузкой.
///
/// Индикатор показывается, только когда страница действительно грузится: иначе
/// он не индикатор, а вечно крутящееся колесо. Когда загрузка не идёт, а
/// история ещё есть, вместо него — кнопка: она же и запасной выход, если
/// автоматический запрос почему-то не сработал.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.loading,
    required this.onLoadMore,
  });

  final bool loading;

  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onLoadMore,
                child: Text(LocaleKeys.common_loadMore.tr()),
              ),
      ),
    );
  }
}
