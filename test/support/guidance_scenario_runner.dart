import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_policies.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

class GuidanceScenario {
  const GuidanceScenario({
    required this.name,
    required this.route,
    required this.mode,
    required this.frames,
  });

  final String name;
  final RoutePlan route;
  final TravelMode mode;
  final List<GuidanceScenarioFrame> frames;
}

class GuidanceScenarioFrame {
  const GuidanceScenarioFrame({
    required this.position,
    this.expectedCurrentStep,
    this.expectedUpcomingStep,
    this.expectedDistanceToManeuverMeters,
    this.distanceToleranceMeters = 15,
    this.expectedDisplayHeadingDegrees,
    this.headingToleranceDegrees = 1,
    this.expectedHeadingSource,
    this.expectedReroute = false,
    this.expectedArrival = false,
  });

  final NavigationPosition position;
  final int? expectedCurrentStep;
  final int? expectedUpcomingStep;
  final double? expectedDistanceToManeuverMeters;
  final double distanceToleranceMeters;
  final double? expectedDisplayHeadingDegrees;
  final double headingToleranceDegrees;
  final NavigationHeadingSource? expectedHeadingSource;
  final bool expectedReroute;
  final bool expectedArrival;
}

class GuidanceReplayFrame {
  const GuidanceReplayFrame({
    required this.update,
    required this.heading,
    required this.announcement,
    required this.reroute,
    required this.arrived,
  });

  final GuidanceUpdate update;
  final NavigationHeadingDecision heading;
  final String? announcement;
  final bool reroute;
  final bool arrived;
}

class GuidanceReplayReport {
  const GuidanceReplayReport({required this.frames});

  final List<GuidanceReplayFrame> frames;

  List<String> get announcements => frames
      .map((frame) => frame.announcement)
      .whereType<String>()
      .toList(growable: false);
}

class GuidanceScenarioRunner {
  const GuidanceScenarioRunner();

  GuidanceReplayReport run(GuidanceScenario scenario) {
    final engine = NavigationEngine(scenario.route, scenario.mode);
    final headingTracker = NavigationHeadingTracker(scenario.mode);
    final deviationPolicy = RouteDeviationPolicy(scenario.mode);
    final announcements = GuidanceAnnouncementPlanner();
    final frames = <GuidanceReplayFrame>[];
    NavigationPosition? previousPosition;
    double? previousProgress;
    var completed = false;

    for (final scenarioFrame in scenario.frames) {
      if (completed) break;
      final position = scenarioFrame.position;
      final update = engine.update(
        position,
        previousProgressMeters: previousProgress,
        previousPosition: previousPosition,
      );
      final heading = headingTracker.resolve(
        position,
        routeHeadingDegrees: update.routeHeadingDegrees,
        distanceFromRouteMeters: update.distanceFromRouteMeters,
      );
      deviationPolicy.update(update: update, position: position);
      final arrived = deviationPolicy.hasArrived;
      final announcement = announcements.next(
        update: update,
        route: scenario.route,
        mode: scenario.mode,
      );
      frames.add(
        GuidanceReplayFrame(
          update: update,
          heading: heading,
          announcement: announcement,
          reroute: deviationPolicy.shouldReroute(position.timestamp),
          arrived: arrived,
        ),
      );
      previousProgress = update.progressMeters;
      previousPosition = position;
      completed = arrived;
    }
    return GuidanceReplayReport(frames: frames);
  }
}

class GuidanceScenarioOracle {
  const GuidanceScenarioOracle();

  void verify(GuidanceScenario scenario, GuidanceReplayReport report) {
    expect(report.frames, hasLength(lessThanOrEqualTo(scenario.frames.length)));
    double? previousProgress;
    final announcements = <String>{};
    for (var index = 0; index < report.frames.length; index++) {
      final actual = report.frames[index];
      final expected = scenario.frames[index];
      final progress = actual.update.progressMeters;
      if (previousProgress != null) {
        expect(
          progress,
          greaterThanOrEqualTo(previousProgress),
          reason: '${scenario.name}, frame $index: progression non monotone',
        );
      }
      previousProgress = progress;
      if (expected.expectedCurrentStep case final value?) {
        expect(
          actual.update.currentStepIndex,
          value,
          reason: '${scenario.name}, frame $index: étape courante',
        );
      }
      if (expected.expectedUpcomingStep case final value?) {
        expect(
          actual.update.upcomingStepIndex,
          value,
          reason: '${scenario.name}, frame $index: prochaine étape',
        );
      }
      if (expected.expectedDistanceToManeuverMeters case final value?) {
        expect(
          actual.update.distanceToManeuverMeters,
          closeTo(value, expected.distanceToleranceMeters),
          reason: '${scenario.name}, frame $index: distance à la manœuvre',
        );
      }
      if (expected.expectedDisplayHeadingDegrees case final value?) {
        expect(
          _angleDifference(actual.heading.displayHeadingDegrees, value),
          lessThanOrEqualTo(expected.headingToleranceDegrees),
          reason: '${scenario.name}, frame $index: cap affiché',
        );
      }
      if (expected.expectedHeadingSource case final value?) {
        expect(
          actual.heading.source,
          value,
          reason: '${scenario.name}, frame $index: source du cap',
        );
      }
      expect(
        actual.reroute,
        expected.expectedReroute,
        reason: '${scenario.name}, frame $index: recalcul',
      );
      expect(
        actual.arrived,
        expected.expectedArrival,
        reason: '${scenario.name}, frame $index: arrivée',
      );
      final announcement = actual.announcement;
      if (announcement != null) {
        final announcementKey =
            '${actual.update.upcomingStepIndex}:$announcement';
        expect(
          announcements.add(announcementKey),
          isTrue,
          reason: '${scenario.name}, frame $index: annonce répétée',
        );
      }
    }
  }
}

double _angleDifference(double first, double second) {
  final difference = (first - second).abs() % 360;
  return difference > 180 ? 360 - difference : difference;
}
