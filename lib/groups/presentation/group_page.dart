import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routemaster/routemaster.dart';

import '../../chat/models/chat_target.dart';
import '../../chat/presentation/chat_page.dart';
import '../../chat/state_management/chat_bloc.dart';
import '../../chat/state_management/chat_events.dart';
import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../models/group.dart';
import '../state_management/group_feed_bloc.dart';
import '../state_management/group_feed_events.dart';
import '../state_management/group_feed_state.dart';
import '../state_management/groups_bloc.dart';

/// Экран группы: две вкладки — «Чат» и «События».
///
/// Разговор больше не спрятан за кнопкой в шапке ленты: в группе одинаково
/// нужны обе стороны, и переключаться между ними надо одним касанием, а не
/// открытием и закрытием отдельного экрана. Первой идёт вкладка чата, она же
/// открывается по умолчанию: в группу заходят разговаривать, а лента событий
/// — сводка, за которой возвращаются реже.
///
/// Вкладки адресуемые (routemaster [TabPage]): у чата путь
/// `/groups/:id/feed/chat`, у ленты — `/groups/:id/feed/events`, так что
/// ссылка из пуша по-прежнему открывает разговор, только уже вкладкой.
/// Переключение вкладки оставляет запись в истории — по той же причине, что и
/// в нижней навигации: иначе «назад» в вебе выбрасывает с сайта.
///
/// Оба Bloc'а живут здесь, над вкладками: PageView сносит невидимую вкладку с
/// дерева, и разговор перечитывался бы целиком при каждом переключении.
/// Провайдеры ленивые: при переходе сразу на `/groups/:id/feed/events` вкладка
/// чата не строится, и [ChatOpened] (он помечает сообщения прочитанными) не
/// случается за спиной у пользователя.
class GroupPage extends StatelessWidget {
  const GroupPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<GroupFeedBloc>(param1: groupId)..add(const GroupFeedOpened()),
        ),
        BlocProvider(
          create: (_) => getIt<ChatBloc>(param1: GroupChatTarget(groupId))
            ..add(ChatOpened()),
        ),
      ],
      child: _GroupView(groupId: groupId),
    );
  }
}

class _GroupView extends StatelessWidget {
  const _GroupView({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    // TabPage.of подписывает на смену вкладки: шапка меняет свои кнопки вместе
    // с ней (колокольчик — только у чата, «нет связи» — только у ленты).
    final tabs = TabPage.of(context);
    final onChat = tabs.index == 0;
    final feed = context.watch<GroupFeedBloc>().state;
    final group = _group(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(feed, group)),
        actions: [
          // Колокольчик читает ChatBloc — поэтому он и появляется только на
          // вкладке чата: иначе разговор открывался бы (и помечался
          // прочитанным) вместе с группой.
          if (onChat) const ChatNotificationsButton(),
          // Честно про live-соединение ленты: список читается и без него, он
          // просто перестаёт обновляться сам.
          if (!onChat && feed.loaded && !feed.live)
            IconButton(
              tooltip: LocaleKeys.groups_feed_offline.tr(),
              onPressed: () =>
                  context.read<GroupFeedBloc>().add(const GroupFeedRefreshed()),
              icon: const Icon(Icons.cloud_off_outlined),
            ),
          // Управление группой: «Участники» доступны всем, «Приглашение» —
          // только владельцу (признак берётся из myGroups в общем GroupsBloc).
          // Навигация через onSelected: контекст пункта меню к моменту
          // срабатывания уже снят с дерева вместе с самим меню.
          PopupMenuButton<String>(
            onSelected: (item) =>
                Routemaster.of(context).push('/groups/$groupId/feed/$item'),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'members',
                child: Text(LocaleKeys.groups_members.tr()),
              ),
              if (group?.viewerIsOwner ?? false)
                PopupMenuItem(
                  value: 'invite',
                  child: Text(LocaleKeys.groups_invite_title.tr()),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: tabs.controller,
          tabs: [
            Tab(
              child: _ChatTabLabel(
                // Непрочитанное берётся из myGroups: пока вкладку не открыли,
                // о чате известно только оттуда. Открытая вкладка сама себя
                // обнуляет — на ней сообщения уже прочитаны.
                unread: onChat ? 0 : (group?.chatUnreadCount ?? 0),
              ),
            ),
            Tab(text: LocaleKeys.groups_tabs_events.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs.controller,
        children: [
          for (final stack in tabs.stacks) PageStackNavigator(stack: stack),
        ],
      ),
    );
  }

  /// Эта группа в общем списке `myGroups` — оттуда берутся признак владельца и
  /// счётчик непрочитанного; сам экран группу целиком не загружает.
  Group? _group(BuildContext context) {
    for (final group in context.watch<GroupsBloc>().state.groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  /// Название группы: лента приносит его первым же ответом, до этого выручает
  /// список групп, а если нет и его — общий заголовок.
  String _title(GroupFeedState feed, Group? group) {
    if (feed.groupName.isNotEmpty) return feed.groupName;
    if ((group?.name ?? '').isNotEmpty) return group!.name;
    return LocaleKeys.groups_feed_title.tr();
  }
}

/// Подпись вкладки чата со значком непрочитанного.
class _ChatTabLabel extends StatelessWidget {
  const _ChatTabLabel({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final label = Text(LocaleKeys.groups_tabs_chat.tr());
    if (unread <= 0) return label;
    return Badge.count(
      count: unread,
      // Значок висит справа от подписи, а не поверх неё.
      child: Padding(padding: const EdgeInsets.only(right: 12), child: label),
    );
  }
}
