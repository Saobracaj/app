import 'link_sources_state.dart';

/// События админки источников ссылок.
sealed class LinkSourcesEvent {}

/// Открыть экран: загрузить источники и воронку.
class LinkSourcesStarted extends LinkSourcesEvent {}

/// Перечитать всё.
class LinkSourcesRefreshed extends LinkSourcesEvent {}

/// Сменить период воронки.
class LinkSourcesPeriodChanged extends LinkSourcesEvent {
  LinkSourcesPeriodChanged(this.period);
  final StatsPeriod period;
}

/// Показать или скрыть архивные источники.
class LinkSourcesArchivedShown extends LinkSourcesEvent {
  LinkSourcesArchivedShown(this.show);
  final bool show;
}

/// Завести источник. Пустой [code] — код придумает бэкенд.
class LinkSourceCreated extends LinkSourcesEvent {
  LinkSourceCreated({
    required this.name,
    required this.description,
    required this.code,
    required this.targetPath,
  });

  final String name;
  final String description;
  final String code;
  final String targetPath;
}

/// Изменить название, описание или экран назначения.
class LinkSourceEdited extends LinkSourcesEvent {
  LinkSourceEdited({
    required this.id,
    required this.name,
    required this.description,
    required this.targetPath,
  });

  final String id;
  final String name;
  final String description;
  final String targetPath;
}

/// Убрать в архив или вернуть.
class LinkSourceArchiveToggled extends LinkSourcesEvent {
  LinkSourceArchiveToggled(this.id, {required this.archived});
  final String id;
  final bool archived;
}

/// Экран показал ссылку нового источника — больше не нужно.
class LinkSourceCreatedShown extends LinkSourcesEvent {}
