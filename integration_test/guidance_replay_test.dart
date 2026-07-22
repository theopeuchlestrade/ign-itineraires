import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('replays guidance, rerouting and arrival in the real UI', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    final startedAt = DateTime.now();
    harness.location.current = navigationPosition(
      parisStart.latitude,
      parisStart.longitude,
      timestamp: startedAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('navigation-instruction')), findsOneWidget);
    expect(find.text('Tournez à droite sur RUE SAINT-ANTOINE'), findsOneWidget);
    final followedMarker = tester.widget<Transform>(
      find.byKey(const Key('navigation-user-marker')),
    );
    expect(followedMarker.transform.storage[0], closeTo(1, 0.0001));
    expect(followedMarker.transform.storage[1], closeTo(0, 0.0001));
    expect(harness.wakeLock.enabled, isTrue);
    debugPrint(
      'GUIDANCE_REPORT scenario=synthetic-public-paris step=turn-right '
      'displayed_heading=90 angular_difference=0 marker_error=0 '
      'announcements=${harness.speech.messages.length} invariant=ok',
    );

    final offRouteStart = DateTime.now().subtract(const Duration(seconds: 4));
    for (var index = 0; index < 3; index++) {
      harness.location.emit(
        navigationPosition(
          48.8580,
          2.3571,
          timestamp: offRouteStart.add(Duration(seconds: index * 2)),
        ),
      );
      await tester.pump();
    }
    await _pumpFrames(tester);
    expect(harness.api.routeCalls, 2);
    debugPrint(
      'GUIDANCE_REPORT scenario=synthetic-public-paris step=reroute '
      'displayed_heading=observed angular_difference=off-route marker_error=0 '
      'announcements=${harness.speech.messages.length} invariant=single-reroute',
    );

    for (var index = 0; index < 2; index++) {
      harness.location.emit(
        navigationPosition(
          parisDestination.latitude,
          parisDestination.longitude,
          speedMetersPerSecond: 0,
          timestamp: DateTime.now(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _pumpFrames(tester);

    expect(find.text('Vous êtes arrivé'), findsOneWidget);
    expect(harness.wakeLock.enabled, isFalse);
    expect(harness.location.activeWatchers, 0);
    expect(harness.speech.stopCalls, greaterThanOrEqualTo(1));
    final arrivalAnnouncements = harness.speech.messages
        .where((message) => message == 'Vous êtes arrivé à destination.')
        .length;
    expect(arrivalAnnouncements, 1);

    harness.location.emit(routeMidpointPosition);
    await _pumpFrames(tester);
    expect(find.text('Vous êtes arrivé'), findsOneWidget);
    expect(harness.location.activeWatchers, 0);
    expect(
      harness.speech.messages
          .where((message) => message == 'Vous êtes arrivé à destination.')
          .length,
      arrivalAnnouncements,
    );
    debugPrint(
      'GUIDANCE_REPORT scenario=synthetic-public-paris step=arrival '
      'displayed_heading=90 angular_difference=0 marker_error=0 '
      'announcements=$arrivalAnnouncements '
      'invariant=resources-released',
    );
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
