import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/auth/presentation/widgets/social_sign_in_buttons.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );

/// Минимальная непрозрачность в дереве: выключенная кнопка приглушается.
double _minOpacity(WidgetTester tester) => tester
    .widgetList<Opacity>(find.byType(Opacity))
    .map((o) => o.opacity)
    .fold<double>(1, (a, b) => a < b ? a : b);

void main() {
  testWidgets('кнопка со спиннером показывает только индикатор', (tester) async {
    await _pump(
      tester,
      GoogleSignInButton(onPressed: null, busy: true),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Крутящаяся кнопка не приглушается — иначе спиннер выглядит выключенным.
    expect(_minOpacity(tester), 1);
  });

  testWidgets('выключенная кнопка приглушена и не крутит спиннер',
      (tester) async {
    await _pump(
      tester,
      AppleSignInButton(onPressed: null, busy: false),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_minOpacity(tester), lessThan(1));
  });

  testWidgets('по выключенной кнопке нельзя нажать', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      GoogleSignInButton(onPressed: null, busy: false),
    );
    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();
    expect(taps, 0);

    await _pump(
      tester,
      GoogleSignInButton(onPressed: () => taps++, busy: false),
    );
    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();
    expect(taps, 1);
  });
}
