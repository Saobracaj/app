import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:saobracaj/main.dart';

/// Состояние истории браузера в wasm-сборке (задача 1217510064568188).
///
/// В wasm типы настоящие: то, что ушло в `history.pushState`, возвращается
/// картой `Map<Object?, Object?>` с числами-`double`. Приведения внутри
/// `RouteData.fromRouteInformation` на таком падают, и кнопки «назад/вперёд»
/// перестают двигать приложение. Здесь проверяется, что состояние приводится
/// к ожидаемым типам ещё до разбора.

/// Как состояние приходит из браузера в wasm-сборке.
Map<Object?, Object?> _fromBrowser() => <Object?, Object?>{
  'isReplacement': false,
  'internalPath': '/settings/appearance',
  'requestSource': 'RequestSource.internal',
  'pathTemplate': '/settings/:section',
  'pathParameters': <Object?, Object?>{'section': 'appearance'},
  'historyIndex': 3.0,
  'appSession': 'abc123',
};

void main() {
  test('карта и вложенные карты становятся Map<String, dynamic>', () {
    final state = normalizeHistoryState(_fromBrowser());

    expect(state, isA<Map<String, dynamic>>());
    expect((state! as Map)['pathParameters'], isA<Map<String, dynamic>>());
  });

  test('целые числа перестают быть double', () {
    final state = normalizeHistoryState(_fromBrowser())! as Map;

    expect(state['historyIndex'], isA<int>());
    expect(state['historyIndex'], 3);
  });

  test('строки, флаги и дробные числа не трогаются', () {
    final state =
        normalizeHistoryState(<Object?, Object?>{
              'internalPath': '/home',
              'isReplacement': true,
              'ratio': 1.5,
              'nothing': null,
            })!
            as Map;

    expect(state['internalPath'], '/home');
    expect(state['isReplacement'], isTrue);
    expect(state['ratio'], 1.5);
    expect(state['nothing'], isNull);
  });

  test('routemaster разбирает приведённое состояние без ошибки типов', () {
    // Именно этот разбор падал в Chrome: до приведения — «Runtime type check
    // failed», после — обычный RouteData с индексом истории.
    final data = RouteData.fromRouteInformation(
      RouteInformation(
        uri: Uri.parse('/settings/appearance'),
        state: normalizeHistoryState(_fromBrowser()),
      ),
    );

    expect(data.path, '/settings/appearance');
    expect(data.pathParameters['section'], 'appearance');
  });

  test('сырое состояние из браузера routemaster разобрать не может', () {
    expect(
      () => RouteData.fromRouteInformation(
        RouteInformation(
          uri: Uri.parse('/settings/appearance'),
          state: _fromBrowser(),
        ),
      ),
      throwsA(isA<TypeError>()),
    );
  });
}
