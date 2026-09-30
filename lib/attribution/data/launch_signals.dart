/// Что платформа знает о том, откуда взялась эта копия приложения.
///
/// За условным импортом: мобильная половина ходит в `package_info_plus` и в
/// плагин Google Play Install Referrer, которых в вебе нет, а веб читает
/// параметр `lnk` из адресной строки.
library;

export 'launch_signals_stub.dart' if (dart.library.io) 'launch_signals_io.dart';
