import 'package:flutter/foundation.dart';

import 'navigation_models.dart';
import 'routing_models.dart';

class NavigationSignalPolicy {
  NavigationSignalPolicy({required this.mode, required this.now});

  final TravelMode mode;
  final DateTime Function() now;
  int _rejectedFixes = 0;
  int _recoveryFixes = 0;

  String? issueFor(NavigationPosition position) {
    if (position.precision == LocationPrecision.reduced) {
      return 'Localisation approximative activée. Autorisez la position précise '
          'dans les réglages ou utilisez une application GPS externe.';
    }
    if (position.isMocked && !kDebugMode) {
      return 'Une position simulée a été détectée. Le guidage est suspendu.';
    }
    final age = now().difference(position.timestamp);
    if (age > const Duration(seconds: 5) || age < const Duration(seconds: -2)) {
      return 'La position GPS reçue est trop ancienne. Recherche d’un signal récent…';
    }
    final maximumAccuracy = mode == TravelMode.pedestrian ? 25.0 : 35.0;
    if (!position.accuracyMeters.isFinite ||
        position.accuracyMeters > maximumAccuracy) {
      return 'Précision GPS insuffisante '
          '(${position.accuracyMeters.round()} m). Guidage suspendu.';
    }
    return null;
  }

  NavigationSignalState reject({
    required NavigationPosition position,
    required NavigationSignalState currentSignalState,
  }) {
    _rejectedFixes++;
    _recoveryFixes = 0;
    if (position.precision == LocationPrecision.reduced) {
      return NavigationSignalState.reduced;
    }
    return _rejectedFixes >= 3
        ? NavigationSignalState.degraded
        : currentSignalState;
  }

  bool needsRecoveryConfirmation(NavigationSignalState signalState) {
    if (signalState != NavigationSignalState.degraded &&
        signalState != NavigationSignalState.interrupted &&
        signalState != NavigationSignalState.reduced) {
      return false;
    }
    _recoveryFixes++;
    return _recoveryFixes < 2;
  }

  void accept() {
    _rejectedFixes = 0;
    _recoveryFixes = 0;
  }

  void reset() {
    _rejectedFixes = 0;
    _recoveryFixes = 0;
  }
}

class RouteDeviationPolicy {
  RouteDeviationPolicy(this.mode);

  final TravelMode mode;
  int _offRouteFixes = 0;
  int _reverseDirectionFixes = 0;
  int _arrivalFixes = 0;
  DateTime? _offRouteSince;

  bool get hasArrived => _arrivalFixes >= 2;

  void update({
    required GuidanceUpdate update,
    required NavigationPosition position,
  }) {
    final offRouteThreshold = mode == TravelMode.pedestrian ? 15.0 : 25.0;
    final certainlyOffRoute =
        update.distanceFromRouteMeters - position.accuracyMeters >
        offRouteThreshold;
    if (certainlyOffRoute) {
      _offRouteFixes++;
      _offRouteSince ??= position.timestamp;
    } else {
      _offRouteFixes = 0;
      _offRouteSince = null;
    }
    _reverseDirectionFixes = update.reverseDirection
        ? _reverseDirectionFixes + 1
        : 0;
    _arrivalFixes = update.arrived && position.accuracyMeters <= 20
        ? _arrivalFixes + 1
        : 0;
  }

  bool shouldReroute(DateTime timestamp) {
    final offRouteSince = _offRouteSince;
    final offRouteLongEnough =
        offRouteSince != null &&
        timestamp.difference(offRouteSince) >= const Duration(seconds: 4);
    return (_offRouteFixes >= 3 && offRouteLongEnough) ||
        _reverseDirectionFixes >= 3;
  }

  void clearOffRouteFixes() {
    _offRouteFixes = 0;
  }

  void reset() {
    _offRouteFixes = 0;
    _reverseDirectionFixes = 0;
    _arrivalFixes = 0;
    _offRouteSince = null;
  }
}

class ReroutePolicy {
  DateTime? _lastRerouteAt;

  bool markAttempt(DateTime now, {required bool force}) {
    if (!force &&
        _lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < const Duration(seconds: 20)) {
      return false;
    }
    _lastRerouteAt = now;
    return true;
  }
}
