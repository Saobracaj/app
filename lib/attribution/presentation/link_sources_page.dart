import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../generated/locale_keys.g.dart';
import '../models/link_source.dart';
import '../state_management/link_sources_bloc.dart';
import '../state_management/link_sources_events.dart';
import '../state_management/link_sources_state.dart';
import 'link_source_editor.dart';

/// Источники ссылок (настройки › «Источники ссылок»): заводим место, где
/// раздаётся ссылка, получаем `…/go/<код>` и смотрим воронку — переходы,
/// открытия приложения, регистрации и покупки. Виден держателям
/// `manage_attribution`; право проверяет бэкенд на каждом запросе.
class LinkSourcesPage extends StatelessWidget {
  const LinkSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.linkSources_title.tr())),
      body: const SafeArea(child: LinkSourcesContent()),
    );
  }
}

/// Содержимое без Scaffold — и для отдельного экрана, и для правой панели
/// настроек (там ему нужна ограниченная высота: список со своей прокруткой).
class LinkSourcesContent extends StatelessWidget {
  const LinkSourcesContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LinkSourcesBloc>()..add(LinkSourcesStarted()),
      child: const _LinkSourcesView(),
    );
  }
}

class _LinkSourcesView extends StatelessWidget {
  const _LinkSourcesView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LinkSourcesBloc, LinkSourcesState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null &&
              curr.errorMessage != prev.errorMessage) ||
          (curr.infoMessage != null && curr.infoMessage != prev.infoMessage) ||
          (curr.created != null && curr.created != prev.created),
      listener: (context, state) {
        final created = state.created;
        if (created != null) {
          context.read<LinkSourcesBloc>().add(LinkSourceCreatedShown());
          showDialog<void>(
            context: context,
            builder: (_) => _CreatedDialog(source: created),
          );
          return;
        }
        final message = state.errorMessage ?? state.infoMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(state: state),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _SourceList(state: state)),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state});

  final LinkSourcesState state;

  static String _periodLabel(StatsPeriod period) => switch (period) {
    StatsPeriod.allTime => LocaleKeys.linkSources_periodAll.tr(),
    StatsPeriod.days30 => LocaleKeys.linkSources_period30.tr(),
    StatsPeriod.days7 => LocaleKeys.linkSources_period7.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LinkSourcesBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: state.submitting
                ? null
                : () async {
                    final result = await showLinkSourceEditor(context);
                    if (result == null) return;
                    bloc.add(
                      LinkSourceCreated(
                        name: result.name,
                        description: result.description,
                        code: result.code,
                        targetPath: result.targetPath,
                      ),
                    );
                  },
            icon: const Icon(Icons.add_link),
            label: Text(LocaleKeys.linkSources_newSource.tr()),
          ),
          for (final period in StatsPeriod.values)
            ChoiceChip(
              label: Text(_periodLabel(period)),
              selected: state.period == period,
              onSelected: (_) => bloc.add(LinkSourcesPeriodChanged(period)),
            ),
          FilterChip(
            label: Text(LocaleKeys.linkSources_showArchived.tr()),
            selected: state.showArchived,
            onSelected: (show) => bloc.add(LinkSourcesArchivedShown(show)),
          ),
          IconButton(
            tooltip: LocaleKeys.linkSources_refresh.tr(),
            onPressed: state.loading
                ? null
                : () => bloc.add(LinkSourcesRefreshed()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({required this.state});

  final LinkSourcesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(
        LocaleKeys.linkSources_note.tr(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (!state.loading && state.sources.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          note,
          const SizedBox(height: 24),
          Text(
            LocaleKeys.linkSources_empty.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: state.sources.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return note;
        final source = state.sources[index - 1];
        return _SourceCard(
          source: source,
          stats: state.statsOf(source.id),
          busy: state.submitting,
        );
      },
    );
  }
}

enum _SourceAction { edit, archive, restore }

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.stats,
    required this.busy,
  });

  final LinkSource source;
  final LinkSourceStats stats;
  final bool busy;

  Future<void> _onAction(BuildContext context, _SourceAction action) async {
    final bloc = context.read<LinkSourcesBloc>();
    switch (action) {
      case _SourceAction.edit:
        final result = await showLinkSourceEditor(context, source: source);
        if (result == null) return;
        bloc.add(
          LinkSourceEdited(
            id: source.id,
            name: result.name,
            description: result.description,
            targetPath: result.targetPath,
          ),
        );
      case _SourceAction.archive:
        bloc.add(LinkSourceArchiveToggled(source.id, archived: true));
      case _SourceAction.restore:
        bloc.add(LinkSourceArchiveToggled(source.id, archived: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = context.locale.toString();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(source.name, style: theme.textTheme.titleMedium),
                ),
                if (source.archived)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text(LocaleKeys.linkSources_archivedBadge.tr()),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                PopupMenuButton<_SourceAction>(
                  enabled: !busy,
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _SourceAction.edit,
                      child: Text(LocaleKeys.linkSources_edit.tr()),
                    ),
                    if (source.archived)
                      PopupMenuItem(
                        value: _SourceAction.restore,
                        child: Text(LocaleKeys.linkSources_restore.tr()),
                      )
                    else
                      PopupMenuItem(
                        value: _SourceAction.archive,
                        child: Text(LocaleKeys.linkSources_archive.tr()),
                      ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.linkSources_createdAt.tr(
                      args: [DateFormat.yMMMd(locale).format(source.createdAt)],
                    ),
                    style: muted,
                  ),
                  if (source.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(source.description),
                  ],
                  const SizedBox(height: 8),
                  _LinkRow(url: source.url),
                  if (source.targetPath != '/')
                    Text(
                      LocaleKeys.linkSources_leadsTo.tr(
                        args: [source.targetPath],
                      ),
                      style: muted,
                    ),
                  const SizedBox(height: 12),
                  _Funnel(stats: stats),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ссылка источника и кнопка «скопировать».
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            url,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        IconButton(
          tooltip: LocaleKeys.linkSources_copy.tr(),
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () => copyLinkToClipboard(context, url),
        ),
      ],
    );
  }
}

Future<void> copyLinkToClipboard(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(LocaleKeys.linkSources_copied.tr())));
}

/// Воронка источника: переходы → открыли приложение (новые установки и уже
/// установленные) → регистрации → покупатели. Доли — от переходов.
class _Funnel extends StatelessWidget {
  const _Funnel({required this.stats});

  final LinkSourceStats stats;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    String share(int value) {
      if (stats.clicks == 0) return '';
      final percent = value * 100 / stats.clicks;
      final pattern = percent < 10 && percent > 0 ? '0.0' : '0';
      return '${NumberFormat(pattern, locale).format(percent)}%';
    }

    return Column(
      children: [
        _FunnelRow(
          label: LocaleKeys.linkSources_funnelClicks.tr(),
          value: stats.clicks,
          detail: LocaleKeys.linkSources_funnelClicksSplit.tr(
            args: [
              '${stats.clicksAndroid}',
              '${stats.clicksIos}',
              '${stats.clicksWeb}',
            ],
          ),
        ),
        _FunnelRow(
          label: LocaleKeys.linkSources_funnelReached.tr(),
          value: stats.reached,
          share: share(stats.reached),
        ),
        _FunnelRow(
          label: LocaleKeys.linkSources_funnelInstalls.tr(),
          value: stats.installs,
          detail: stats.installsProbable > 0
              ? LocaleKeys.linkSources_funnelProbable.tr(
                  args: ['${stats.installsProbable}'],
                )
              : null,
          nested: true,
        ),
        _FunnelRow(
          label: LocaleKeys.linkSources_funnelOpens.tr(),
          value: stats.opens,
          detail: stats.opensProbable > 0
              ? LocaleKeys.linkSources_funnelProbable.tr(
                  args: ['${stats.opensProbable}'],
                )
              : null,
          nested: true,
        ),
        _FunnelRow(
          label: LocaleKeys.linkSources_funnelRegistrations.tr(),
          value: stats.registrations,
          share: share(stats.registrations),
        ),
        _FunnelRow(
          label: LocaleKeys.linkSources_funnelBuyers.tr(),
          value: stats.buyers,
          share: share(stats.buyers),
          detail: stats.purchases > stats.buyers
              ? LocaleKeys.linkSources_funnelPurchases.tr(
                  args: ['${stats.purchases}'],
                )
              : null,
        ),
      ],
    );
  }
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow({
    required this.label,
    required this.value,
    this.share = '',
    this.detail,
    this.nested = false,
  });

  final String label;
  final int value;
  final String share;
  final String? detail;

  /// Подстрока предыдущей строки — с отступом и мельче.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final labelStyle = nested
        ? theme.textTheme.bodySmall?.copyWith(color: muted)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(left: nested ? 16 : 0, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                style: labelStyle,
                children: [
                  if (detail != null)
                    TextSpan(
                      text: '  $detail',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
          ),
          if (share.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                share,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          SizedBox(
            width: 56,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style:
                  (nested
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.titleSmall)
                      ?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Источник создан: вот его ссылка.
class _CreatedDialog extends StatelessWidget {
  const _CreatedDialog({required this.source});

  final LinkSource source;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(LocaleKeys.linkSources_createdTitle.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LocaleKeys.linkSources_createdBody.tr(args: [source.name])),
          const SizedBox(height: 12),
          SelectableText(
            source.url,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(LocaleKeys.linkSources_close.tr()),
        ),
        FilledButton.icon(
          onPressed: () async {
            await copyLinkToClipboard(context, source.url);
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.copy_rounded),
          label: Text(LocaleKeys.linkSources_copy.tr()),
        ),
      ],
    );
  }
}
