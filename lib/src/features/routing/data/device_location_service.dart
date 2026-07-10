import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

abstract interface class DeviceLocationGateway {
  Future<Place> currentPlace();

  Future<NavigationPosition> currentPosition({TravelMode? navigationMode});

  Stream<NavigationPosition> watchPositions(TravelMode mode);
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message, {this.permanentlyDenied = false});

  final String message;
  final bool permanentlyDenied;

  @override
  String toString() => message;
}

class DeviceLocationService implements DeviceLocationGateway {
  DeviceLocationService({
    DateTime Function()? now,
    this.precisionCacheDuration = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration precisionCacheDuration;
  LocationPrecision _precision = LocationPrecision.unknown;
  DateTime? _precisionReadAt;
  Future<LocationPrecision>? _pendingPrecisionRead;

  @override
  Future<Place> currentPlace() async {
    return (await currentPosition()).asPlace;
  }

  @override
  Future<NavigationPosition> currentPosition({
    TravelMode? navigationMode,
  }) async {
    await _ensurePermission();
    _precision = await _refreshPrecision(force: true);
    try {
      final position =
          navigationMode == null || _precision == LocationPrecision.reduced
          ? await Geolocator.getCurrentPosition(
              locationSettings: _settings(
                navigationMode,
                timeLimit: Duration(seconds: navigationMode == null ? 15 : 20),
              ),
            )
          : await Geolocator.getPositionStream(
                  locationSettings: _settings(
                    navigationMode,
                    timeLimit: const Duration(seconds: 20),
                  ),
                )
                .firstWhere(
                  (position) =>
                      position.accuracy.isFinite &&
                      position.accuracy <=
                          (navigationMode == TravelMode.pedestrian ? 25 : 35) &&
                      _now().difference(position.timestamp).abs() <=
                          const Duration(seconds: 5),
                )
                .timeout(const Duration(seconds: 20));
      return _fromGeolocator(position, precision: _precision);
    } catch (_) {
      throw const DeviceLocationException(
        'Votre position n’a pas pu être déterminée. Saisissez un départ.',
      );
    }
  }

  @override
  Stream<NavigationPosition> watchPositions(TravelMode mode) {
    unawaited(_refreshPrecision(force: true));
    return Geolocator.getPositionStream(
      locationSettings: _settings(mode),
    ).asyncMap((position) async {
      final precision = await _refreshPrecision();
      return _fromGeolocator(position, precision: precision);
    });
  }

  LocationSettings _settings(TravelMode? mode, {Duration? timeLimit}) {
    final navigation = mode != null;
    final accuracy = navigation
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.high;
    final distanceFilter = switch (mode) {
      TravelMode.pedestrian => 3,
      TravelMode.car => 5,
      null => 0,
    };
    if (kIsWeb) {
      return WebSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        maximumAge: Duration.zero,
        timeLimit: timeLimit,
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: navigation ? const Duration(seconds: 1) : null,
        timeLimit: timeLimit,
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: mode == TravelMode.car
            ? ActivityType.automotiveNavigation
            : mode == TravelMode.pedestrian
            ? ActivityType.fitness
            : ActivityType.other,
        pauseLocationUpdatesAutomatically: !navigation,
        showBackgroundLocationIndicator: false,
        allowBackgroundLocationUpdates: false,
        timeLimit: timeLimit,
      ),
      _ => LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
      ),
    };
  }

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        'Activez la localisation de votre appareil pour utiliser votre position.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        'La localisation est nécessaire pour choisir votre position comme départ.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'La localisation est bloquée. Autorisez-la dans les réglages de l’application.',
        permanentlyDenied: true,
      );
    }
  }

  NavigationPosition _fromGeolocator(
    Position position, {
    required LocationPrecision precision,
  }) {
    return NavigationPosition(
      point: LatLng(position.latitude, position.longitude),
      accuracyMeters: position.accuracy.isFinite ? position.accuracy : 999,
      headingDegrees: position.heading.isFinite ? position.heading : 0,
      headingAccuracyDegrees: position.headingAccuracy.isFinite
          ? position.headingAccuracy
          : 999,
      speedMetersPerSecond: position.speed.isFinite && position.speed > 0
          ? position.speed
          : 0,
      speedAccuracyMetersPerSecond: position.speedAccuracy.isFinite
          ? position.speedAccuracy
          : 999,
      timestamp: position.timestamp,
      precision: precision,
      isMocked: position.isMocked,
    );
  }

  Future<LocationPrecision> _readPrecision() async {
    try {
      return switch (await Geolocator.getLocationAccuracy()) {
        LocationAccuracyStatus.precise => LocationPrecision.precise,
        LocationAccuracyStatus.reduced => LocationPrecision.reduced,
        LocationAccuracyStatus.unknown => LocationPrecision.unknown,
      };
    } catch (_) {
      return LocationPrecision.unknown;
    }
  }

  Future<LocationPrecision> _refreshPrecision({bool force = false}) {
    final readAt = _precisionReadAt;
    final fresh =
        readAt != null && _now().difference(readAt) < precisionCacheDuration;
    if (!force && fresh) return Future.value(_precision);
    final pending = _pendingPrecisionRead;
    if (pending != null) return pending;

    final future = _readPrecision().then((precision) {
      _precision = precision;
      _precisionReadAt = _now();
      return precision;
    });
    _pendingPrecisionRead = future;
    return future.whenComplete(() {
      if (identical(_pendingPrecisionRead, future)) {
        _pendingPrecisionRead = null;
      }
    });
  }
}
