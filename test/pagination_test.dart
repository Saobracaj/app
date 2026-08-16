import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saobracaj/core/presentation/pagination.dart';

/// Список из [items] строк в [PaginationTrigger], считающий запросы страниц.
Widget _list({
  required int items,
  required bool enabled,
  required VoidCallback onLoadMore,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PaginationTrigger(
        enabled: enabled,
        onLoadMore: onLoadMore,
        child: ListView.builder(
          itemCount: items,
          itemBuilder: (_, index) =>
              SizedBox(height: 80, child: Text('$index')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a list too short to scroll still asks for the next page', (
    tester,
  ) async {
    var requests = 0;
    // Три строки по 80 точек в экране теста (600 точек высотой) — прокручивать
    // нечего, событий прокрутки не будет, и без реакции на метрики следующая
    // страница не запросилась бы никогда.
    await tester.pumpWidget(
      _list(items: 3, enabled: true, onLoadMore: () => requests++),
    );
    await tester.pumpAndSettle();

    expect(requests, greaterThan(0));
  });

  testWidgets('nothing is asked for when there is nothing left to load', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      _list(items: 3, enabled: false, onLoadMore: () => requests++),
    );
    await tester.pumpAndSettle();

    expect(requests, 0);
  });

  testWidgets('a long list asks for the next page only near its end', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      _list(items: 40, enabled: true, onLoadMore: () => requests++),
    );
    await tester.pumpAndSettle();
    expect(requests, 0, reason: 'the end of the list is far below');

    await tester.drag(find.byType(ListView), const Offset(0, -2600));
    await tester.pumpAndSettle();

    expect(requests, greaterThan(0));
  });

  testWidgets('the footer spins only while a page is actually loading', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadMoreFooter(loading: false, onLoadMore: () => requests++),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(TextButton));
    expect(requests, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoadMoreFooter(loading: true, onLoadMore: () {})),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
