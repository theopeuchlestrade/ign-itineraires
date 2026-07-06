import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/address_search_field.dart';

import 'support/test_fixtures.dart';

void main() {
  testWidgets('waits for three characters and the debounce delay', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host((query) async {
        calls++;
        return const [parisStart];
      }),
    );

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 349));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(calls, 1);
    expect(find.text(parisStart.label), findsOneWidget);
  });

  testWidgets('ignores a stale response received after a newer search', (
    tester,
  ) async {
    final first = Completer<List<Place>>();
    final second = Completer<List<Place>>();
    await tester.pumpWidget(
      _host((query) => query == 'Paris' ? first.future : second.future),
    );

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'Bastille');
    await tester.pump(const Duration(milliseconds: 350));

    second.complete(const [parisDestination]);
    await tester.pump();
    first.complete(const [parisStart]);
    await tester.pump();

    expect(find.text(parisDestination.label), findsOneWidget);
    expect(find.text(parisStart.label), findsNothing);
  });

  testWidgets('hides suggestions when search fails or returns nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host((_) => Future<List<Place>>.error(Exception('offline'))),
    );

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Future<List<Place>> Function(String) search) {
  return MaterialApp(
    home: Scaffold(
      body: AddressSearchField(
        label: 'Départ',
        icon: Icons.trip_origin,
        value: null,
        search: search,
        onChanged: (_) {},
      ),
    ),
  );
}
