import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    expect(find.text('Recherche indisponible. Réessayez.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a response completed after a suggestion is selected', (
    tester,
  ) async {
    final pending = Completer<List<Place>>();
    var calls = 0;
    await tester.pumpWidget(
      _host((_) {
        calls++;
        return calls == 1 ? Future.value(const [parisStart]) : pending.future;
      }),
    );

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Bastille');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text(parisStart.label));
    await tester.pump();

    pending.complete(const [parisDestination]);
    await tester.pump();

    expect(find.text(parisDestination.label), findsNothing);
    expect(find.text(parisStart.label), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
  });

  testWidgets('announces an empty result', (tester) async {
    await tester.pumpWidget(_host((_) async => const []));

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Aucun résultat.'), findsOneWidget);
  });

  testWidgets('selects suggestions with arrow keys and Enter', (tester) async {
    Place? selected;
    await tester.pumpWidget(
      _host(
        (_) async => const [parisStart, parisDestination],
        onChanged: (value) => selected = value,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, parisStart);
    expect(find.text(parisStart.label), findsOneWidget);
    expect(find.text(parisDestination.label), findsNothing);
    await tester.pump(const Duration(milliseconds: 180));
  });

  testWidgets('keeps suggestions tappable while the keyboard loses focus', (
    tester,
  ) async {
    Place? selected;
    await tester.pumpWidget(
      _host(
        (_) async => const [parisDestination],
        onChanged: (value) => selected = value,
      ),
    );

    await tester.enterText(find.byType(TextField), 'Bastille');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(parisDestination.label), findsOneWidget);
    await tester.tap(find.text(parisDestination.label));
    await tester.pump();

    expect(selected, parisDestination);
  });

  for (final size in [const Size(390, 844), const Size(360, 640)]) {
    testWidgets(
      'scrolls mobile suggestions in both directions at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _useCompactSurface(tester, size);
        Place? selected;
        await tester.pumpWidget(
          _host(
            (_) async => _mobileSuggestions,
            onChanged: (value) => selected = value,
          ),
        );

        final launcher = find.byKey(
          const ValueKey('mobile-address-launcher-Départ'),
        );
        expect(launcher, findsOneWidget);
        await tester.tap(launcher);
        await tester.pumpAndSettle();
        final searchInput = find.byKey(
          const ValueKey('mobile-address-search-input'),
        );
        expect(searchInput, findsOneWidget);
        await tester.enterText(
          find.descendant(of: searchInput, matching: find.byType(EditableText)),
          'Paris',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        final list = find.byKey(const ValueKey('mobile-address-suggestions'));
        final first = find.byKey(const ValueKey('mobile-address-suggestion-0'));
        final last = find.byKey(const ValueKey('mobile-address-suggestion-5'));
        expect(first.hitTestable(), findsOneWidget);

        await tester.drag(list, const Offset(0, -260));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: searchInput,
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isFalse,
        );
        expect(list, findsOneWidget);
        expect(last.hitTestable(), findsOneWidget);

        await tester.drag(list, const Offset(0, 260));
        await tester.pumpAndSettle();
        expect(first.hitTestable(), findsOneWidget);

        await tester.drag(list, const Offset(0, -260));
        await tester.pumpAndSettle();
        await tester.tap(last.hitTestable());
        await tester.pumpAndSettle();

        expect(selected, _mobileSuggestions.last);
        expect(searchInput, findsNothing);
        expect(find.text(_mobileSuggestions.last.label), findsOneWidget);
      },
    );
  }

  testWidgets('prefills, cancels, replaces, and clears a mobile selection', (
    tester,
  ) async {
    await _useCompactSurface(tester, const Size(390, 844));
    final changes = <Place?>[];
    await tester.pumpWidget(
      _host(
        (_) async => const [parisDestination],
        value: parisStart,
        onChanged: changes.add,
      ),
    );

    final launcher = find.byKey(
      const ValueKey('mobile-address-launcher-Départ'),
    );
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    var searchInput = find.byKey(const ValueKey('mobile-address-search-input'));
    var editable = tester.widget<EditableText>(
      find.descendant(of: searchInput, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, parisStart.label);
    expect(
      editable.controller.selection,
      TextSelection(baseOffset: 0, extentOffset: parisStart.label.length),
    );

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.text(parisStart.label), findsOneWidget);

    await tester.tap(launcher);
    await tester.pumpAndSettle();
    searchInput = find.byKey(const ValueKey('mobile-address-search-input'));
    await tester.enterText(
      find.descendant(of: searchInput, matching: find.byType(EditableText)),
      'Bastille',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text(parisDestination.label));
    await tester.pumpAndSettle();
    expect(changes, [parisDestination]);
    expect(find.text(parisDestination.label), findsOneWidget);

    await tester.tap(launcher);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Effacer départ'));
    await tester.pumpAndSettle();
    expect(changes, [parisDestination, null]);
    expect(
      find.byKey(const ValueKey('mobile-address-search-input')),
      findsNothing,
    );
  });

  testWidgets('mobile search has no overflow at 200 percent text scale', (
    tester,
  ) async {
    await _useCompactSurface(tester, const Size(390, 844), textScale: 2);
    await tester.pumpWidget(_host((_) async => _mobileSuggestions));

    await tester.tap(
      find.byKey(const ValueKey('mobile-address-launcher-Départ')),
    );
    await tester.pumpAndSettle();
    final searchInput = find.byKey(
      const ValueKey('mobile-address-search-input'),
    );
    await tester.enterText(
      find.descendant(of: searchInput, matching: find.byType(EditableText)),
      'Paris',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('mobile-address-suggestions')),
      findsOneWidget,
    );
  });
}

Widget _host(
  Future<List<Place>> Function(String) search, {
  ValueChanged<Place?>? onChanged,
  Place? value,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AddressSearchField(
        label: 'Départ',
        icon: Icons.trip_origin,
        value: value,
        search: search,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

Future<void> _useCompactSurface(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
  tester.view.viewInsets = FakeViewPadding(
    bottom: size.height < 700 ? 280 : 350,
  );
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() async {
    tester.view.resetViewInsets();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(null);
  });
}

const _mobileSuggestions = [
  Place(label: 'Paris Centre 1', latitude: 48.851, longitude: 2.351),
  Place(label: 'Paris Centre 2', latitude: 48.852, longitude: 2.352),
  Place(label: 'Paris Centre 3', latitude: 48.853, longitude: 2.353),
  Place(label: 'Paris Centre 4', latitude: 48.854, longitude: 2.354),
  Place(label: 'Paris Centre 5', latitude: 48.855, longitude: 2.355),
  Place(label: 'Paris Centre 6', latitude: 48.856, longitude: 2.356),
];
