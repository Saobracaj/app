import 'package:saobracaj/data/zakon_o_bezbednosti_data_source.dart';

/// Документ, который умеет показывать виджет [Zakon]: закон о безопасности
/// дорожного движения или правилник о дорожной сигнализации. У обоих одна
/// схема строк (глава/член/абзац) и одинаковые ссылки — отличаются заголовок,
/// источник данных и путь, на который указывает скопированная ссылка.
enum LawDocument {
  zakonOBezbednosti(
    title: 'ЗАКОН о безбедности саобраћаја на путевима',
    linkPath: '/zakon',
    hasTranslation: true,
  ),
  pravilnik(
    title: 'ПРАВИЛНИК о саобраћајној сигнализацији',
    linkPath: '/pravilnik',
    // Русского перевода правилника (пока) нет — кнопка «РУ» не показывается.
    hasTranslation: false,
  );

  const LawDocument({
    required this.title,
    required this.linkPath,
    required this.hasTranslation,
  });

  final String title;
  final String linkPath;
  final bool hasTranslation;

  ZakonDataSource get dataSource => switch (this) {
    LawDocument.zakonOBezbednosti => zakonOBezbednostiDataSource,
    LawDocument.pravilnik => pravilnikDataSource,
  };
}
