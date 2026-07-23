import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/navigation_page.dart';
import 'package:ign_itineraires/src/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

import 'support/fakes.dart';
import 'support/test_fixtures.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('uses the opposite heading for a heading-up camera', () {
    expect(navigationCameraRotationDegrees(0), 0);
    expect(navigationCameraRotationDegrees(90), -90);
    expect(navigationCameraRotationDegrees(180), -180);
    expect(navigationCameraRotationDegrees(270), -270);
    expect(navigationCameraRotationDegrees(359), -359);
    expect(navigationCameraRotationDegrees(1), -1);
  });

  test('keeps the vehicle aligned while following or exploring the map', () {
    expect(
      navigationMarkerRotationDegrees(
        followingUser: true,
        headingDegrees: 270,
        mapRotationDegrees: -270,
      ),
      0,
    );
    expect(
      navigationMarkerRotationDegrees(
        followingUser: false,
        headingDegrees: 270,
        mapRotationDegrees: -270,
      ),
      0,
    );
    expect(
      navigationMarkerRotationDegrees(
        followingUser: false,
        headingDegrees: 0,
        mapRotationDegrees: -270,
      ),
      90,
    );
  });

  test('derives a roundabout exit angle from geometry or modifier', () {
    const geometryStep = RouteStep(
      type: 'roundabout',
      modifier: 'straight',
      roadName: '',
      distanceMeters: 40,
      points: [LatLng(0, 0), LatLng(0.001, 0), LatLng(0.001, 0.001)],
      exitNumber: 2,
    );
    const fallbackStep = RouteStep(
      type: 'roundabout',
      modifier: 'left',
      roadName: '',
      distanceMeters: 40,
      points: [],
      exitNumber: 3,
    );

    expect(roundaboutExitAngleDegrees(geometryStep), closeTo(90, 1));
    expect(roundaboutExitAngleDegrees(fallbackStep), -90);
  });

  test('updates the followed camera when only heading changes', () {
    final previous = _navigationSession(headingDegrees: 10);
    final current = _navigationSession(headingDegrees: 45);

    expect(shouldUpdateNavigationCamera(previous, current), isTrue);
    expect(
      shouldUpdateNavigationCamera(
        current,
        current.copyWith(followingUser: false),
      ),
      isFalse,
    );
  });

  test('diagnostics expose heading decisions without coordinates', () {
    final session = _navigationSession(headingDegrees: 90).copyWith(
      currentStepIndex: 1,
      distanceToManeuverMeters: 42,
      signalState: NavigationSignalState.reliable,
      headingDecision: const NavigationHeadingDecision(
        gpsHeadingDegrees: 82,
        movementHeadingDegrees: 88,
        routeHeadingDegrees: 90,
        displayHeadingDegrees: 90,
        source: NavigationHeadingSource.routeAligned,
        angularDifferenceDegrees: 2,
      ),
    );

    final text = buildGuidanceDiagnosticsText(session);

    expect(text, contains('GPS 82°'));
    expect(text, contains('retenu 90° (route alignée)'));
    expect(text, contains('Manœuvre 42 m'));
    expect(text, isNot(contains('48.85')));
    expect(text, isNot(contains('2.35')));
  });

  testWidgets('toggles coordinate-free diagnostics with the build flag', (
    tester,
  ) async {
    const diagnosticsEnabled = bool.fromEnvironment('GUIDANCE_DIAGNOSTICS');
    final harness = TestAppHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.byKey(const Key('guidance-diagnostics')),
      diagnosticsEnabled ? findsOneWidget : findsNothing,
    );
  });

  test('uses maneuver-specific navigation icons', () {
    const roundabout = RouteStep(
      type: 'roundabout',
      modifier: 'right',
      roadName: '',
      distanceMeters: 20,
      points: [],
      exitNumber: 2,
    );
    const slightLeft = RouteStep(
      type: 'turn',
      modifier: 'slight left',
      roadName: '',
      distanceMeters: 20,
      points: [],
    );

    expect(
      navigationInstructionIcon(roundabout),
      Icons.roundabout_right_rounded,
    );
    expect(
      navigationInstructionIcon(slightLeft),
      Icons.turn_slight_left_rounded,
    );
  });

  testWidgets('renders the live map before MapController is ready', (
    tester,
  ) async {
    final position = NavigationPosition(
      point: const LatLng(48.85, 2.35),
      accuracyMeters: 5,
      headingDegrees: 90,
      speedMetersPerSecond: 4,
      timestamp: DateTime(2026),
    );
    final session = NavigationSession(
      status: NavigationStatus.active,
      destination: const Place(
        label: 'Destination',
        latitude: 48.851,
        longitude: 2.36,
      ),
      mode: TravelMode.car,
      voiceEnabled: true,
      route: const RoutePlan(
        points: [LatLng(48.85, 2.35), LatLng(48.851, 2.36)],
        distanceMeters: 800,
        durationSeconds: 300,
        steps: [],
        resourceVersion: 'test',
      ),
      position: position,
      snappedPosition: position.point,
      remainingDistanceMeters: 800,
      remainingDurationSeconds: 300,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: buildLiveNavigationMapForTest(session),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final marker = tester.widget<Transform>(
      find.byKey(const Key('navigation-user-marker')),
    );
    expect(marker.transform.storage[0], closeTo(1, 0.0001));
    expect(marker.transform.storage[1], closeTo(0, 0.0001));
  });

  testWidgets('rotates the marker against the map in free view', (
    tester,
  ) async {
    final session = _navigationSession(
      headingDegrees: 90,
    ).copyWith(followingUser: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildLiveNavigationMapForTest(
            session,
            initialMapRotationDegrees: 30,
          ),
        ),
      ),
    );
    await tester.pump();

    final marker = tester.widget<Transform>(
      find.byKey(const Key('navigation-user-marker')),
    );
    expect(marker.transform.storage[0], closeTo(-0.5, 0.01));
    expect(marker.transform.storage[1], closeTo(0.866, 0.01));
  });

  testWidgets('shows a message when external guidance fails', (tester) async {
    final harness = TestAppHarness()..externalNavigation.launchResult = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Ouvrir dans une autre application'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();

    expect(harness.externalNavigation.launchCalls, 1);
    expect(find.text('Impossible d’ouvrir le guidage.'), findsOneWidget);

    await harness.dispose();
  });

  testWidgets('offers an actionable retry after a speech error', (
    tester,
  ) async {
    final harness = TestAppHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    harness.speech.errorHandler?.call('not-allowed');
    await tester.pump();

    expect(find.text('Réessayer la voix'), findsOneWidget);
    final beforeRetry = harness.speech.messages.length;
    await tester.tap(find.text('Réessayer la voix'));
    await tester.pump();

    expect(harness.speech.messages, hasLength(beforeRetry + 1));
    await harness.dispose();
  });

  testWidgets('retries navigation after a route service failure', (
    tester,
  ) async {
    final harness = TestAppHarness()
      ..api.routeError = const GeoplateformeException(
        'Connexion impossible',
        kind: GeoplateformeFailureKind.offline,
      );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Guidage indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    harness.api.routeError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Guidage indisponible'), findsNothing);
    expect(_initialManeuverDistance(), findsOneWidget);
    expect(harness.api.routeCalls, 2);
  });

  testWidgets('keeps guidance at the top and trip metrics at the bottom', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
          now: () => DateTime(2026, 1, 1, 14, 2),
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final instructionCard = find.ancestor(
      of: _initialManeuverDistance(),
      matching: find.byType(Card),
    );
    final metricsCard = find.ancestor(
      of: find.text('Arrivée'),
      matching: find.byType(Card),
    );

    expect(tester.getTopLeft(instructionCard).dy, lessThan(80));
    expect(
      tester.getBottomRight(metricsCard).dy,
      moreOrLessEquals(832, epsilon: 1),
    );
  });

  testWidgets('shows one large control for each navigation action', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Arrêter'), findsOneWidget);
    expect(find.text('Autre GPS'), findsOneWidget);
    expect(find.byTooltip('Arrêter le guidage'), findsNothing);
    expect(find.byTooltip('Recentrer sur ma position'), findsNothing);
    final voiceControl = find.ancestor(
      of: find.byTooltip('Couper les instructions vocales'),
      matching: find.byType(IconButton),
    );
    final overviewControl = find.ancestor(
      of: find.byTooltip('Voir tout le trajet'),
      matching: find.byType(FloatingActionButton),
    );
    expect(tester.getSize(voiceControl), const Size.square(56));
    expect(tester.getSize(overviewControl), const Size.square(56));
    final externalSize = tester.getSize(
      find.byKey(const ValueKey('navigation-external-button')),
    );
    final stopSize = tester.getSize(
      find.byKey(const ValueKey('navigation-stop-button')),
    );
    expect(externalSize.width, greaterThanOrEqualTo(56));
    expect(externalSize.height, greaterThanOrEqualTo(56));
    expect(stopSize.width, greaterThanOrEqualTo(56));
    expect(stopSize.height, greaterThanOrEqualTo(56));

    await tester.tap(find.byTooltip('Voir tout le trajet'));
    await tester.pump();

    final recenter = find.ancestor(
      of: find.byTooltip('Recentrer sur ma position'),
      matching: find.byType(FloatingActionButton),
    );
    expect(recenter, findsOneWidget);
    expect(tester.getSize(recenter), const Size.square(56));
  });

  testWidgets('does not duplicate a detailed GPS warning with its badge', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('GPS fiable'), findsOneWidget);
    harness.location.emit(
      navigationPosition(
        48.8566,
        2.3571,
        accuracyMeters: 80,
        timestamp: DateTime.now(),
      ),
    );
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.text('Précision GPS insuffisante (80 m). Guidage suspendu.'),
      findsOneWidget,
    );
    expect(find.textContaining('GPS fiable'), findsNothing);
  });

  testWidgets('uses one accessible numbered roundabout instruction', (
    tester,
  ) async {
    final harness = TestAppHarness()..api.route = _roundaboutRoute;
    harness.location.current = navigationPosition(
      parisStart.latitude,
      parisStart.longitude,
      headingDegrees: 0,
    );
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('3e'), findsOneWidget);
    expect(
      find.text('Au rond-point, prenez la 3e sortie sur RUE DE TEST'),
      findsOneWidget,
    );
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(
        RegExp(r'\d+ m, Au rond-point, prenez la 3e sortie sur RUE DE TEST'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('numbered roundabout visual matches its mobile golden', (
    tester,
  ) async {
    final harness = TestAppHarness()..api.route = _roundaboutRoute;
    harness.location.current = navigationPosition(
      parisStart.latitude,
      parisStart.longitude,
      headingDegrees: 0,
    );
    addTearDown(harness.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
          now: () => DateTime(2026, 1, 1, 14, 2),
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/navigation_roundabout_mobile_light.png'),
    );
  }, tags: const ['golden']);

  testWidgets('asks for confirmation on the system back action', (
    tester,
  ) async {
    final harness = TestAppHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: NavigationPage(
          destination: parisDestination,
          mode: TravelMode.car,
          dependencies: harness.dependencies,
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Arrêter le guidage ?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Arrêter'),
      ),
      findsOneWidget,
    );
  });
}

const _roundaboutRoute = RoutePlan(
  points: [
    LatLng(48.8566, 2.3522),
    LatLng(48.8575, 2.3522),
    LatLng(48.8575, 2.3532),
    LatLng(48.8569, 2.3622),
  ],
  distanceMeters: 1000,
  durationSeconds: 600,
  resourceVersion: 'roundabout-test',
  steps: [
    RouteStep(
      type: 'depart',
      modifier: 'straight',
      roadName: 'RUE A',
      distanceMeters: 100,
      points: [LatLng(48.8566, 2.3522), LatLng(48.8575, 2.3522)],
    ),
    RouteStep(
      type: 'roundabout',
      modifier: 'right',
      roadName: 'RUE DE TEST',
      distanceMeters: 100,
      points: [
        LatLng(48.8575, 2.3522),
        LatLng(48.8580, 2.3522),
        LatLng(48.8580, 2.3532),
      ],
      exitNumber: 3,
    ),
    RouteStep(
      type: 'continue',
      modifier: 'straight',
      roadName: 'RUE DE TEST',
      distanceMeters: 800,
      points: [LatLng(48.8580, 2.3532), LatLng(48.8569, 2.3622)],
    ),
  ],
);

NavigationSession _navigationSession({required double headingDegrees}) {
  final position = NavigationPosition(
    point: const LatLng(48.85, 2.35),
    accuracyMeters: 5,
    headingDegrees: headingDegrees,
    speedMetersPerSecond: 4,
    timestamp: DateTime(2026),
  );
  return NavigationSession(
    status: NavigationStatus.active,
    destination: parisDestination,
    mode: TravelMode.car,
    voiceEnabled: true,
    route: urbanRoute,
    position: position,
    snappedPosition: position.point,
    displayHeadingDegrees: headingDegrees,
  );
}

Finder _initialManeuverDistance() => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data != null &&
      RegExp(r'^49\d m$').hasMatch(widget.data!),
);
