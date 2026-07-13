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
      upcomingStep = math.min(currentStep + 1, _route.steps.length - 1);
      distanceToManeuver = currentStep < _track.stepEndDistances.length
          ? math
                .max(0, _track.stepEndDistances[currentStep] - progress)
                .toDouble()
          : remaining;
      if (upcomingStep == currentStep) distanceToManeuver = remaining;
    }

    final arrivalThreshold = _mode == TravelMode.pedestrian ? 20.0 : 30.0;
    final rawDistanceToDestination = const Distance().as(
      LengthUnit.Meter,
      position.point,
      _route.points.last,
    );

    return GuidanceUpdate(
      snappedPosition: projection.point,
      progressMeters: progress,
      distanceFromRouteMeters: projection.distanceMeters,
      currentStepIndex: currentStep,
      upcomingStepIndex: upcomingStep,
      distanceToManeuverMeters: distanceToManeuver,
      remainingDistanceMeters: remaining,
      remainingDurationSeconds: duration,
      arrived: rawDistanceToDestination <= arrivalThreshold && remaining <= 80,
      routeHeadingDegrees: projection.routeHeadingDegrees,
      reverseDirection:
          position.hasReliableHeading &&
          _angleDifference(
                position.headingDegrees,
                projection.routeHeadingDegrees,
              ) >
              100,
    );
  }

  double _maximumAdvance(double speed, Duration? elapsed) {
    final seconds = elapsed == null
        ? 1.0
        : elapsed.inMilliseconds.clamp(0, 10000) / 1000;
    return math.max(120, speed * seconds * 4 + 80).clamp(120, 500).toDouble();
  }
}

class GuidanceAnnouncementPlanner {
  final Map<int, Set<int>> _announcedThresholds = {};
  bool _initialAnnounced = false;
  bool _arrivalAnnounced = false;

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
    if (update.arrived) {
      if (_arrivalAnnounced) return null;
      _arrivalAnnounced = true;
      return 'Vous êtes arrivé à destination.';
    }
    if (route.steps.isEmpty) return null;

    final stepIndex = update.upcomingStepIndex;
    final step = route.steps[stepIndex];
    if (step.type == 'arrive' && update.remainingDistanceMeters > 80) {
      return null;
    }
    final thresholds = _thresholds(mode);
    final announced = _announcedThresholds.putIfAbsent(
      stepIndex,
      () => <int>{},
    );
    final distance = update.distanceToManeuverMeters;
    final near = thresholds.last;
    final far = thresholds.first;

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
    if (step.type == 'arrive' && remainingDistanceMeters > 80) {
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
    _initialAnnounced = false;
    _arrivalAnnounced = false;
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
    stepEndDistances = route.steps
        .map((step) {
          stepTotal += step.distanceMeters * stepScale;
          return stepTotal;
        })
        .toList(growable: false);
  }

  final RoutePlan route;
  late final List<double> _segmentLengths;
  late final List<double> _cumulativeGeometryDistances;
  late final double _routeScale;
  late final List<double> stepEndDistances;

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

double _angleDifference(double first, double second) {
  final difference = (first - second).abs() % 360;
  return math.min(difference, 360 - difference);
}
