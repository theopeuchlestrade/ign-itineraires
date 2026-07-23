import 'dart:math' as math;

import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

class NavigationEngine {
  NavigationEngine(RoutePlan route, this._mode)
    : _route = route,
      _track = _NavigationTrack(route);

  final RoutePlan _route;
  final TravelMode _mode;
  final _NavigationTrack _track;

  GuidanceUpdate update(
    NavigationPosition position, {
    double? previousProgressMeters,
    NavigationPosition? previousPosition,
  }) {
    final projection = _track.project(
      position.point,
      previousProgressMeters: previousProgressMeters,
      headingDegrees: position.hasReliableHeading
          ? position.headingDegrees
          : null,
      speedMetersPerSecond: position.speedMetersPerSecond,
      elapsed: previousPosition == null
          ? null
          : position.timestamp.difference(previousPosition.timestamp),
    );
    final maximumAdvance = _maximumAdvance(
      position.speedMetersPerSecond,
      previousPosition == null
          ? null
          : position.timestamp.difference(previousPosition.timestamp),
    );
    final progress = previousProgressMeters == null
        ? projection.progressMeters
        : projection.progressMeters.clamp(
            previousProgressMeters,
            previousProgressMeters + maximumAdvance,
          );
    final remaining = math.max(0, _route.distanceMeters - progress).toDouble();
    final duration = _route.distanceMeters <= 0
        ? 0.0
        : _route.durationSeconds * remaining / _route.distanceMeters;

    var currentStep = 0;
    var upcomingStep = 0;
    var distanceToManeuver = remaining;
    if (_route.steps.isNotEmpty) {
      currentStep = _track.stepEndDistances.indexWhere((end) => progress < end);
      if (currentStep == -1) currentStep = _route.steps.length - 1;
      final current = _route.steps[currentStep];
      upcomingStep = current.isRoundabout && current.exitNumber != null
          ? currentStep
          : math.min(currentStep + 1, _route.steps.length - 1);
      distanceToManeuver = currentStep < _track.stepEndDistances.length
          ? math
                .max(0, _track.stepEndDistances[currentStep] - progress)
                .toDouble()
          : remaining;
      if (upcomingStep == currentStep && !current.isRoundabout) {
        distanceToManeuver = remaining;
      }
    }

    final arrivalThreshold = _mode == TravelMode.pedestrian ? 20.0 : 30.0;
    final rawDistanceToDestination = const Distance().as(
      LengthUnit.Meter,
      position.point,
      _route.points.last,
    );
    final inArrivalTail =
        remaining <= 100 ||
        (_route.distanceMeters > 0 && progress / _route.distanceMeters >= 0.95);
    final stationaryAtDestination =
        rawDistanceToDestination <= 10 &&
        position.speedMetersPerSecond.isFinite &&
        position.speedMetersPerSecond < 2;

    return GuidanceUpdate(
      snappedPosition: projection.point,
      progressMeters: progress,
      distanceFromRouteMeters: projection.distanceMeters,
      currentStepIndex: currentStep,
      upcomingStepIndex: upcomingStep,
      distanceToManeuverMeters: distanceToManeuver,
      remainingDistanceMeters: remaining,
      remainingDurationSeconds: duration,
      arrived:
          rawDistanceToDestination <= arrivalThreshold &&
          (inArrivalTail || stationaryAtDestination),
      routeHeadingDegrees: projection.routeHeadingDegrees,
      reverseDirection:
          position.hasReliableHeading &&
          _angleDifference(
                position.headingDegrees,
                projection.routeHeadingDegrees,
              ) >
              100,
      rawDistanceToDestinationMeters: rawDistanceToDestination,
    );
  }

  double _maximumAdvance(double speed, Duration? elapsed) {
    final seconds = elapsed == null
        ? 1.0
        : elapsed.inMilliseconds.clamp(0, 10000) / 1000;
    return math.max(120, speed * seconds * 4 + 80).clamp(120, 500).toDouble();
  }
}

class NavigationHeadingTracker {
  NavigationHeadingTracker(this._mode);

  final TravelMode _mode;
  NavigationPosition? _anchor;
  double? _lastObservedHeadingDegrees;

  void reset() {
    _anchor = null;
    _lastObservedHeadingDegrees = null;
  }

  NavigationHeadingDecision resolve(
    NavigationPosition position, {
    required double routeHeadingDegrees,
    required double distanceFromRouteMeters,
  }) {
    final movementHeading = _movementHeading(position);
    final previousHeading = _lastObservedHeadingDegrees;
    final gpsHeading = _reliablePlatformHeading(position);
    final observed = gpsHeading ?? movementHeading ?? previousHeading;
    final normalizedRoute = _normalizeHeading(routeHeadingDegrees);
    final difference = observed == null
        ? 0.0
        : _angleDifference(observed, normalizedRoute);
    final onRouteThreshold = _mode == TravelMode.pedestrian ? 15.0 : 25.0;
    final confidentlyOnRoute =
        distanceFromRouteMeters - position.accuracyMeters <= onRouteThreshold;

    late final double display;
    late final NavigationHeadingSource source;
    if (observed == null) {
      display = normalizedRoute;
      source = NavigationHeadingSource.routeFallback;
    } else {
      _lastObservedHeadingDegrees = _normalizeHeading(observed);
      if (confidentlyOnRoute && difference < 75) {
        display = normalizedRoute;
        source = NavigationHeadingSource.routeAligned;
      } else {
        display = _lastObservedHeadingDegrees!;
        source = gpsHeading != null
            ? NavigationHeadingSource.gps
            : movementHeading != null
            ? NavigationHeadingSource.movement
            : NavigationHeadingSource.previous;
      }
    }
    return NavigationHeadingDecision(
      gpsHeadingDegrees: gpsHeading == null
          ? null
          : _normalizeHeading(gpsHeading),
      movementHeadingDegrees: movementHeading == null
          ? null
          : _normalizeHeading(movementHeading),
      routeHeadingDegrees: normalizedRoute,
      displayHeadingDegrees: display,
      source: source,
      angularDifferenceDegrees: difference,
    );
  }

  double? _movementHeading(NavigationPosition position) {
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = position;
      return null;
    }
    final elapsed = position.timestamp.difference(anchor.timestamp);
    if (elapsed <= Duration.zero || elapsed > const Duration(seconds: 15)) {
      _anchor = position;
      return null;
    }
    final distance = const Distance().as(
      LengthUnit.Meter,
      anchor.point,
      position.point,
    );
    final worstAccuracy = math.max(
      anchor.accuracyMeters,
      position.accuracyMeters,
    );
    final baseDistance = _mode == TravelMode.car ? 8.0 : 4.0;
    final minimumDistance = math.max(
      baseDistance,
      math.min(20, worstAccuracy * 0.75),
    );
    if (distance < minimumDistance) return null;
    _anchor = position;
    return _bearingBetween(anchor.point, position.point);
  }

  double? _reliablePlatformHeading(NavigationPosition position) {
    if (!position.hasReliableHeading) return null;
    return position.headingDegrees;
  }
}

class GuidanceAnnouncementPlanner {
  final Map<int, Set<int>> _announcedThresholds = {};
  final Set<int> _announcedRoundaboutExits = {};
  bool _initialAnnounced = false;

  String? initial(RoutePlan route) {
    if (_initialAnnounced || route.steps.isEmpty) return null;
    _initialAnnounced = true;
    return route.steps.first.instruction;
  }

  String? next({
    required GuidanceUpdate update,
    required RoutePlan route,
    required TravelMode mode,
  }) {
    if (update.arrived) return null;
    if (route.steps.isEmpty) return null;

    final stepIndex = update.upcomingStepIndex;
    final step = route.steps[stepIndex];
    if (step.normalizedType == 'arrive') return null;
    final thresholds = _thresholds(mode);
    final announced = _announcedThresholds.putIfAbsent(
      stepIndex,
      () => <int>{},
    );
    final distance = update.distanceToManeuverMeters;
    final near = thresholds.last;
    final far = thresholds.first;
    final roundaboutExit = step.roundaboutExitInstruction;

    if (roundaboutExit != null && update.currentStepIndex == stepIndex) {
      final exitThreshold = mode == TravelMode.car ? 80 : 25;
      if (distance <= exitThreshold &&
          _announcedRoundaboutExits.add(stepIndex)) {
        return roundaboutExit;
      }
      return null;
    }

    if (distance <= near && !announced.contains(near)) {
      announced.addAll(thresholds);
      return 'Dans ${_spokenDistance(distance)}, ${_lowercase(step.instruction)}';
    }
    if (distance <= far && !announced.contains(far)) {
      announced.add(far);
      return 'Dans ${_spokenDistance(distance)}, ${_lowercase(step.instruction)}';
    }
    return null;
  }

  String? replayCurrent({
    required int stepIndex,
    required double distanceToManeuverMeters,
    required double remainingDistanceMeters,
    required RoutePlan route,
    required TravelMode mode,
  }) {
    if (route.steps.isEmpty) return null;
    final normalizedIndex = stepIndex.clamp(0, route.steps.length - 1);
    final step = route.steps[normalizedIndex];
    if (step.normalizedType == 'arrive') {
      return 'Continuez vers votre destination';
    }
    final thresholds = _thresholds(mode);
    final announced = _announcedThresholds.putIfAbsent(
      normalizedIndex,
      () => <int>{},
    );
    for (final threshold in thresholds) {
      if (distanceToManeuverMeters <= threshold) announced.add(threshold);
    }
    return step.instruction;
  }

  void reset() {
    _announcedThresholds.clear();
    _announcedRoundaboutExits.clear();
    _initialAnnounced = false;
  }

  List<int> _thresholds(TravelMode mode) =>
      mode == TravelMode.car ? const [300, 60] : const [80, 15];

  String _spokenDistance(double meters) {
    if (meters >= 950) {
      final kilometers = (meters / 1000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '$kilometers kilomètres';
    }
    final rounded = math.max(5, (meters / 5).round() * 5);
    return '$rounded mètres';
  }

  String _lowercase(String value) =>
      value.isEmpty ? value : '${value[0].toLowerCase()}${value.substring(1)}';
}

class _NavigationTrack {
  _NavigationTrack(this.route) {
    if (route.points.length < 2) {
      throw ArgumentError('Un itinéraire doit contenir au moins deux points.');
    }
    _segmentLengths = [];
    _cumulativeGeometryDistances = [0];
    var geometryTotal = 0.0;
    for (var index = 0; index < route.points.length - 1; index++) {
      final length = const Distance().as(
        LengthUnit.Meter,
        route.points[index],
        route.points[index + 1],
      );
      _segmentLengths.add(length);
      geometryTotal += length;
      _cumulativeGeometryDistances.add(geometryTotal);
    }
    _routeScale = geometryTotal <= 0 ? 1 : route.distanceMeters / geometryTotal;

    final rawStepTotal = route.steps.fold<double>(
      0,
      (total, step) => total + step.distanceMeters,
    );
    final stepScale = rawStepTotal <= 0
        ? 1
        : route.distanceMeters / rawStepTotal;
    var stepTotal = 0.0;
    final fallbackStepEndDistances = route.steps
        .map((step) {
          stepTotal += step.distanceMeters * stepScale;
          return stepTotal;
        })
        .toList(growable: false);
    stepEndDistances = _buildStepEndDistances(fallbackStepEndDistances);
  }

  final RoutePlan route;
  late final List<double> _segmentLengths;
  late final List<double> _cumulativeGeometryDistances;
  late final double _routeScale;
  late final List<double> stepEndDistances;

  List<double> _buildStepEndDistances(List<double> fallbackDistances) {
    final result = <double>[];
    var previous = 0.0;
    for (var stepIndex = 0; stepIndex < route.steps.length; stepIndex++) {
      final step = route.steps[stepIndex];
      final fallback = fallbackDistances[stepIndex]
          .clamp(previous, route.distanceMeters)
          .toDouble();
      if (step.points.isEmpty) {
        result.add(fallback);
        previous = fallback;
        continue;
      }

      final endpoint = step.points.last;
      _Projection? best;
      for (
        var segmentIndex = 0;
        segmentIndex < _segmentLengths.length;
        segmentIndex++
      ) {
        final candidate = _projectOnSegment(endpoint, segmentIndex);
        if (candidate.progressMeters + 1 < previous) continue;
        if (best == null || candidate.distanceMeters < best.distanceMeters) {
          best = candidate;
        }
      }
      final projected = best;
      final anchor = projected != null && projected.distanceMeters <= 60
          ? projected.progressMeters
                .clamp(previous, route.distanceMeters)
                .toDouble()
          : fallback;
      result.add(anchor);
      previous = anchor;
    }
    return result;
  }

  _Projection project(
    LatLng position, {
    double? previousProgressMeters,
    double? headingDegrees,
    double speedMetersPerSecond = 0,
    Duration? elapsed,
  }) {
    final seconds = elapsed == null
        ? 1.0
        : elapsed.inMilliseconds.clamp(0, 10000) / 1000;
    final maximumForward = math
        .max(120, speedMetersPerSecond * seconds * 4 + 80)
        .clamp(120, 500);
    _Projection? best;
    var bestScore = double.infinity;
    for (var index = 0; index < _segmentLengths.length; index++) {
      final segmentStart = _cumulativeGeometryDistances[index] * _routeScale;
      final segmentEnd = _cumulativeGeometryDistances[index + 1] * _routeScale;
      if (previousProgressMeters != null &&
          (segmentEnd < previousProgressMeters - 100 ||
              segmentStart > previousProgressMeters + maximumForward)) {
        continue;
      }
      final candidate = _projectOnSegment(position, index);
      final score = _candidateScore(
        candidate,
        previousProgressMeters: previousProgressMeters,
        headingDegrees: headingDegrees,
      );
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    if (best != null) return best;
    for (var index = 0; index < _segmentLengths.length; index++) {
      final candidate = _projectOnSegment(position, index);
      final score = _candidateScore(
        candidate,
        previousProgressMeters: null,
        headingDegrees: headingDegrees,
      );
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best!;
  }

  double _candidateScore(
    _Projection candidate, {
    required double? previousProgressMeters,
    required double? headingDegrees,
  }) {
    var score = candidate.distanceMeters;
    if (headingDegrees != null) {
      score +=
          _angleDifference(headingDegrees, candidate.routeHeadingDegrees) *
          0.35;
    }
    if (previousProgressMeters != null &&
        candidate.progressMeters < previousProgressMeters - 25) {
      score += (previousProgressMeters - 25 - candidate.progressMeters) * 0.5;
    }
    return score;
  }

  _Projection _projectOnSegment(LatLng position, int index) {
    final start = route.points[index];
    final end = route.points[index + 1];
    final latitudeRadians =
        ((start.latitude + end.latitude + position.latitude) / 3) *
        math.pi /
        180;
    final longitudeScale = 111320 * math.cos(latitudeRadians);
    const latitudeScale = 110540.0;
    final segmentX = (end.longitude - start.longitude) * longitudeScale;
    final segmentY = (end.latitude - start.latitude) * latitudeScale;
    final pointX = (position.longitude - start.longitude) * longitudeScale;
    final pointY = (position.latitude - start.latitude) * latitudeScale;
    final lengthSquared = segmentX * segmentX + segmentY * segmentY;
    final fraction = lengthSquared <= 0
        ? 0.0
        : ((pointX * segmentX + pointY * segmentY) / lengthSquared).clamp(
            0.0,
            1.0,
          );
    final closestX = segmentX * fraction;
    final closestY = segmentY * fraction;
    final snapped = LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
    return _Projection(
      point: snapped,
      distanceMeters: math.sqrt(
        math.pow(pointX - closestX, 2) + math.pow(pointY - closestY, 2),
      ),
      progressMeters:
          (_cumulativeGeometryDistances[index] +
              _segmentLengths[index] * fraction) *
          _routeScale,
      routeHeadingDegrees: _bearingDegrees(segmentX, segmentY),
    );
  }
}

class _Projection {
  const _Projection({
    required this.point,
    required this.distanceMeters,
    required this.progressMeters,
    required this.routeHeadingDegrees,
  });

  final LatLng point;
  final double distanceMeters;
  final double progressMeters;
  final double routeHeadingDegrees;
}

double _bearingDegrees(double east, double north) {
  final value = math.atan2(east, north) * 180 / math.pi;
  return (value + 360) % 360;
}

double _bearingBetween(LatLng start, LatLng end) {
  final averageLatitude = (start.latitude + end.latitude) * math.pi / 360;
  final east = (end.longitude - start.longitude) * math.cos(averageLatitude);
  final north = end.latitude - start.latitude;
  return _bearingDegrees(east, north);
}

double _normalizeHeading(double heading) => (heading % 360 + 360) % 360;

double _angleDifference(double first, double second) {
  final difference = (first - second).abs() % 360;
  return math.min(difference, 360 - difference);
}
