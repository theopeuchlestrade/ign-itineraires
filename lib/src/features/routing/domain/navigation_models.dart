import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

enum NavigationStatus {
  acquiringPosition,
  calculating,
  active,
  rerouting,
  paused,
  arrived,
  stopped,
  error,
}

enum LocationPrecision { precise, reduced, unknown }

enum LocationRecovery { openLocationSettings, openAppSettings }

enum NavigationSignalState {
  acquiring,
  reliable,
  degraded,
  reduced,
  interrupted,
}

class NavigationPosition {
  const NavigationPosition({
    required this.point,
    required this.accuracyMeters,
    required this.headingDegrees,
    required this.speedMetersPerSecond,
    required this.timestamp,
    this.headingAccuracyDegrees = 999,
    this.speedAccuracyMetersPerSecond = 999,
    this.precision = LocationPrecision.unknown,
    this.isMocked = false,
  });

  final LatLng point;
  final double accuracyMeters;
  final double headingDegrees;
  final double speedMetersPerSecond;
  final DateTime timestamp;
  final double headingAccuracyDegrees;
  final double speedAccuracyMetersPerSecond;
  final LocationPrecision precision;
  final bool isMocked;

  bool get hasReliableHeading =>
      speedMetersPerSecond >= 1.5 &&
      headingDegrees.isFinite &&
      headingAccuracyDegrees.isFinite &&
      headingAccuracyDegrees <= 30;

  Place get asPlace =>
      Place.current(latitude: point.latitude, longitude: point.longitude);
}

class GuidanceUpdate {
  const GuidanceUpdate({
    required this.snappedPosition,
    required this.progressMeters,
    required this.distanceFromRouteMeters,
    required this.currentStepIndex,
    required this.upcomingStepIndex,
    required this.distanceToManeuverMeters,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.arrived,
    this.routeHeadingDegrees = 0,
    this.reverseDirection = false,
  });

  final LatLng snappedPosition;
  final double progressMeters;
  final double distanceFromRouteMeters;
  final int currentStepIndex;
  final int upcomingStepIndex;
  final double distanceToManeuverMeters;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;
  final bool arrived;
  final double routeHeadingDegrees;
  final bool reverseDirection;
}

class NavigationSession {
  const NavigationSession({
    required this.status,
    required this.destination,
    required this.mode,
    required this.voiceEnabled,
    this.route,
    this.position,
    this.snappedPosition,
    this.currentStepIndex = 0,
    this.upcomingStepIndex = 0,
    this.distanceToManeuverMeters = 0,
    this.remainingDistanceMeters = 0,
    this.remainingDurationSeconds = 0,
    this.distanceFromRouteMeters = 0,
    this.followingUser = true,
    this.signalState = NavigationSignalState.acquiring,
    this.displayHeadingDegrees = 0,
    this.message,
    this.locationRecovery,
  });

  final NavigationStatus status;
  final Place destination;
  final TravelMode mode;
  final bool voiceEnabled;
  final RoutePlan? route;
  final NavigationPosition? position;
  final LatLng? snappedPosition;
  final int currentStepIndex;
  final int upcomingStepIndex;
  final double distanceToManeuverMeters;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;
  final double distanceFromRouteMeters;
  final bool followingUser;
  final NavigationSignalState signalState;
  final double displayHeadingDegrees;
  final String? message;
  final LocationRecovery? locationRecovery;

  RouteStep? get upcomingStep {
    final steps = route?.steps;
    if (steps == null || steps.isEmpty) return null;
    return steps[upcomingStepIndex.clamp(0, steps.length - 1)];
  }

  String get formattedDistanceToManeuver =>
      _formatDistance(distanceToManeuverMeters);

  String get formattedRemainingDistance =>
      _formatDistance(remainingDistanceMeters);

  String get formattedRemainingDuration {
    final minutes = (remainingDurationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours h' : '$hours h $remaining';
  }

  NavigationSession copyWith({
    NavigationStatus? status,
    RoutePlan? route,
    NavigationPosition? position,
    LatLng? snappedPosition,
    int? currentStepIndex,
    int? upcomingStepIndex,
    double? distanceToManeuverMeters,
    double? remainingDistanceMeters,
    double? remainingDurationSeconds,
    double? distanceFromRouteMeters,
    bool? voiceEnabled,
    bool? followingUser,
    NavigationSignalState? signalState,
    double? displayHeadingDegrees,
    Object? message = _unchanged,
    Object? locationRecovery = _unchanged,
  }) {
    return NavigationSession(
      status: status ?? this.status,
      destination: destination,
      mode: mode,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      route: route ?? this.route,
      position: position ?? this.position,
      snappedPosition: snappedPosition ?? this.snappedPosition,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      upcomingStepIndex: upcomingStepIndex ?? this.upcomingStepIndex,
      distanceToManeuverMeters:
          distanceToManeuverMeters ?? this.distanceToManeuverMeters,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
      distanceFromRouteMeters:
          distanceFromRouteMeters ?? this.distanceFromRouteMeters,
      followingUser: followingUser ?? this.followingUser,
      signalState: signalState ?? this.signalState,
      displayHeadingDegrees:
          displayHeadingDegrees ?? this.displayHeadingDegrees,
      message: identical(message, _unchanged)
          ? this.message
          : message as String?,
      locationRecovery: identical(locationRecovery, _unchanged)
          ? this.locationRecovery
          : locationRecovery as LocationRecovery?,
    );
  }

  static String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

const _unchanged = Object();
