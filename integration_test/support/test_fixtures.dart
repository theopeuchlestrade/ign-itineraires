import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:latlong2/latlong.dart';

const parisStart = Place(
  label: 'Hôtel de Ville, Paris',
  latitude: 48.8566,
  longitude: 2.3522,
);

const parisDestination = Place(
  label: 'Place de la Bastille, Paris',
  latitude: 48.8569,
  longitude: 2.3622,
);

const reunionStart = Place(
  label: 'Hôtel de Ville, Saint-Denis, La Réunion',
  latitude: -20.8789,
  longitude: 55.4481,
);

const reunionDestination = Place(
  label: 'Jardin de l’État, Saint-Denis, La Réunion',
  latitude: -20.8872,
  longitude: 55.4505,
);

const urbanRoute = RoutePlan(
  points: [
    LatLng(48.8566, 2.3522),
    LatLng(48.8566, 2.3572),
    LatLng(48.8569, 2.3622),
  ],
  distanceMeters: 1000,
  durationSeconds: 600,
  resourceVersion: 'fixture-2026',
  steps: [
    RouteStep(
      type: 'depart',
      modifier: 'straight',
      roadName: 'RUE DE RIVOLI',
      distanceMeters: 500,
      points: [LatLng(48.8566, 2.3522), LatLng(48.8566, 2.3572)],
    ),
    RouteStep(
      type: 'turn',
      modifier: 'right',
      roadName: 'RUE SAINT-ANTOINE',
      distanceMeters: 500,
      points: [LatLng(48.8566, 2.3572), LatLng(48.8569, 2.3622)],
    ),
    RouteStep(
      type: 'arrive',
      modifier: 'right',
      roadName: 'PLACE DE LA BASTILLE',
      distanceMeters: 0,
      points: [LatLng(48.8569, 2.3622), LatLng(48.8569, 2.3622)],
    ),
  ],
);

NavigationPosition navigationPosition(
  double latitude,
  double longitude, {
  double accuracyMeters = 5,
  double headingDegrees = 90,
  double speedMetersPerSecond = 4,
  double headingAccuracyDegrees = 5,
  DateTime? timestamp,
  LocationPrecision precision = LocationPrecision.precise,
  bool isMocked = false,
}) {
  return NavigationPosition(
    point: LatLng(latitude, longitude),
    accuracyMeters: accuracyMeters,
    headingDegrees: headingDegrees,
    headingAccuracyDegrees: headingAccuracyDegrees,
    speedMetersPerSecond: speedMetersPerSecond,
    speedAccuracyMetersPerSecond: 1,
    timestamp: timestamp ?? DateTime.now(),
    precision: precision,
    isMocked: isMocked,
  );
}

final routeStartPosition = navigationPosition(
  parisStart.latitude,
  parisStart.longitude,
);

final routeMidpointPosition = navigationPosition(48.8566, 2.3571);
final offRoutePosition = navigationPosition(48.8580, 2.3571);
final inaccuratePosition = navigationPosition(
  48.8566,
  2.3571,
  accuracyMeters: 80,
);
final arrivalPosition = navigationPosition(
  parisDestination.latitude,
  parisDestination.longitude,
);
