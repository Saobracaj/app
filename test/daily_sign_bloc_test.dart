import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/home/state_management/daily_sign_bloc.dart';
import 'package:saobracaj/home/state_management/daily_sign_events.dart';
import 'package:saobracaj/zakon/domain/road_sign_index.dart';

/// «Знак дня»: один официальный знак из индекса правилника на день, название
/// скрыто до нажатия.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(RoadSignIndex.reset);

  test('в индексе только знаки с файлом и названием, без повторов', () async {
    final signs = await RoadSignIndex.all();
    expect(signs.length, greaterThan(100));
    for (final sign in signs) {
      expect(sign.asset, startsWith('assets/signs/'));
      expect(sign.nameSr, isNotNull);
    }
    expect(signs.map((s) => s.asset).toSet().length, signs.length);
  });

  test('знак выбирается по дню и открывается по кнопке', () async {
    final signs = await RoadSignIndex.all();
    final bloc = DailySignBloc();
    await withClock(Clock.fixed(DateTime(2026, 9, 28, 9)), () async {
      bloc.add(DailySignStarted());
      await bloc.stream.firstWhere((s) => s.sign != null);
    });
    expect(signs, contains(bloc.state.sign));
    expect(bloc.state.revealed, isFalse);

    // Тот же день позже — тот же знак.
    final again = DailySignBloc();
    await withClock(Clock.fixed(DateTime(2026, 9, 28, 23)), () async {
      again.add(DailySignStarted());
      await again.stream.firstWhere((s) => s.sign != null);
    });
    expect(again.state.sign, same(bloc.state.sign));

    bloc.add(DailySignRevealed());
    await bloc.stream.firstWhere((s) => s.revealed);
    await bloc.close();
    await again.close();
  });
}
