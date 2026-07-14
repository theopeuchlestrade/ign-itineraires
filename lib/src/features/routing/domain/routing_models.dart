import 'dart:convert';

import 'package:latlong2/latlong.dart';

enum TravelMode {
  car,
  pedestrian;

  String get apiValue => switch (this) {
    TravelMode.car => 'car',
    TravelMode.pedestrian => 'pedestrian',
  };

  String get label => switch (this) {
    TravelMode.car => 'Voiture',
    TravelMode.pedestrian => 'À pied',
  };

  String get googleValue => switch (this) {
    TravelMode.car => 'driving',
    TravelMode.pedestrian => 'walking',
  };

  String get appleValue => switch (this) {
    TravelMode.car => 'd',
    TravelMode.pedestrian => 'w',
  };
}

class Place {
  const Place({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  const Place.current({required this.latitude, required this.longitude})
    : label = 'Ma position';

  final String label;
  final double latitude;
  final double longitude;

  LatLng get point => LatLng(latitude, longitude);

  Map<String, Object> toJson() => {
    'label': label,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    label: json['label'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );

  factory Place.fromCompletionJson(Map<String, dynamic> json) {
    final label = json['fulltext'];
    final latitude = (json['y'] as num?)?.toDouble();
    final longitude = (json['x'] as num?)?.toDouble();
    if (label is! String ||
        label.trim().isEmpty ||
        !_validCoordinate(latitude, longitude)) {
      throw const FormatException('Invalid completion result');
    }
    return Place(label: label, latitude: latitude!, longitude: longitude!);
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.label == label &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(label, latitude, longitude);
}

class RouteStep {
  const RouteStep({
    required this.type,
    required this.modifier,
    required this.roadName,
    required this.distanceMeters,
    required this.points,
    this.exitNumber,
  });

  final String type;
  final String modifier;
  final String roadName;
  final double distanceMeters;
  final List<LatLng> points;
  final int? exitNumber;

  String get normalizedType => type.trim().toLowerCase().replaceAll('_', ' ');

  bool get isRoundabout => switch (normalizedType) {
    'roundabout' || 'rotary' || 'roundabout turn' => true,
    _ => false,
  };

  String? get roundaboutExitInstruction {
    final exit = exitNumber;
    if (!isRoundabout || exit == null) return null;
    final road = roadName.isEmpty ? '' : ' sur $roadName';
    return 'Prenez maintenant la ${exit == 1 ? '1re' : '${exit}e'} sortie$road';
  }

  String get instruction {
    final direction = switch (modifier) {
      'left' => 'à gauche',
      'right' => 'à droite',
      'slight left' => 'légèrement à gauche',
      'slight right' => 'légèrement à droite',
      'sharp left' => 'franchement à gauche',
      'sharp right' => 'franchement à droite',
      _ => 'tout droit',
    };
    final road = roadName.isEmpty ? '' : ' sur $roadName';
    final directedTurn = modifier == 'uturn'
        ? 'Faites demi-tour$road'
        : modifier == 'straight'
        ? 'Continuez tout droit$road'
        : 'Tournez $direction$road';
    final exit = exitNumber;
    final roundaboutInstruction = exit == null
        ? 'Entrez dans le rond-point${roadName.isEmpty ? '' : road}'
        : 'Au rond-point, prenez la ${exit == 1 ? '1re' : '${exit}e'} sortie'
              '${roadName.isEmpty ? '' : road}';

    return switch (normalizedType) {
      'depart' =>
        modifier == 'straight'
            ? 'Partez tout droit$road'
            : roadName.isEmpty
            ? 'Partez'
            : 'Partez$road',
      'arrive' =>
        'Vous êtes arrivé${modifier == 'left'
            ? ' sur votre gauche'
            : modifier == 'right'
            ? ' sur votre droite'
            : ''}',
      'turn' => directedTurn,
      'merge' =>
        modifier == 'straight'
            ? 'Insérez-vous$road'
            : 'Insérez-vous $direction$road',
      'ramp' || 'on ramp' =>
        modifier == 'straight'
            ? 'Prenez la bretelle$road'
            : 'Prenez la bretelle $direction$road',
      'off ramp' =>
        modifier == 'straight'
            ? 'Prenez la sortie$road'
            : 'Prenez la sortie $direction$road',
      'fork' =>
        modifier == 'left' || modifier == 'slight left'
            ? 'À l’embranchement, tenez la gauche$road'
            : modifier == 'right' || modifier == 'slight right'
            ? 'À l’embranchement, tenez la droite$road'
            : 'À l’embranchement, continuez tout droit$road',
      'end of road' =>
        modifier == 'uturn'
            ? 'Au bout de la route, faites demi-tour$road'
            : 'Au bout de la route, tournez $direction$road',
      'roundabout' || 'rotary' || 'roundabout turn' => roundaboutInstruction,
      'exit roundabout' || 'exit rotary' =>
        roadName.isEmpty ? 'Sortez du rond-point' : 'Sortez du rond-point$road',
      'new name' =>
        modifier == 'straight' ? 'Continuez$road' : 'Continuez $direction$road',
      'continue' => 'Continuez $direction$road',
      'notification' || 'use lane' =>
        modifier == 'straight'
            ? 'Continuez tout droit$road'
            : 'Continuez $direction$road',
      _ => directedTurn,
    };
  }

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final instruction =
        json['instruction'] as Map<String, dynamic>? ?? const {};
    final attributes = json['attributes'] as Map<String, dynamic>? ?? const {};
    final name = attributes['name'] as Map<String, dynamic>? ?? const {};
    final left = (name['nom_1_gauche'] as String? ?? '').trim();
    final right = (name['nom_1_droite'] as String? ?? '').trim();
    final geometry = json['geometry'] as Map<String, dynamic>? ?? const {};
    final coordinates = geometry['coordinates'] as List<dynamic>? ?? const [];

    return RouteStep(
      type: instruction['type'] as String? ?? 'continue',
      modifier: instruction['modifier'] as String? ?? 'straight',
      roadName: left.isNotEmpty ? left : right,
      distanceMeters: (json['distance'] as num? ?? 0).toDouble(),
      exitNumber: switch (instruction['exit']) {
        final num value when value.toInt() > 0 => value.toInt(),
        _ => null,
      },
      points: coordinates
          .map((coordinate) {
            final pair = coordinate as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          })
          .toList(growable: false),
    );
  }
}

class RoutePlan {
  const RoutePlan({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.resourceVersion,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final String resourceVersion;

  String get formattedDistance => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours h' : '$hours h $remaining';
  }

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    if (geometry is! Map<String, dynamic> ||
        geometry['type'] != 'LineString' ||
        geometry['coordinates'] is! List<dynamic>) {
      throw const FormatException('Invalid route geometry');
    }
    final coordinates = geometry['coordinates'] as List<dynamic>;
    if (coordinates.length < 2) {
      throw const FormatException('Route geometry is too short');
    }
    final distance = (json['distance'] as num?)?.toDouble();
    final duration = (json['duration'] as num?)?.toDouble();
    if (distance == null ||
        duration == null ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0) {
      throw const FormatException('Invalid route metrics');
    }
    final portions = json['portions'] as List<dynamic>? ?? const [];
    final steps = <RouteStep>[];
    for (final portion in portions) {
      final portionMap = portion as Map<String, dynamic>;
      for (final step in portionMap['steps'] as List<dynamic>? ?? const []) {
        steps.add(RouteStep.fromJson(step as Map<String, dynamic>));
      }
    }

    return RoutePlan(
      points: coordinates.map(_coordinateFromJson).toList(growable: false),
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
      resourceVersion: json['resourceVersion'] as String? ?? '',
    );
  }
}

class RecentRoute {
  const RecentRoute({
    required this.start,
    required this.destination,
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.createdAt,
  });

  final Place start;
  final Place destination;
  final TravelMode mode;
  final double distanceMeters;
  final double durationSeconds;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'start': start.toJson(),
    'destination': destination.toJson(),
    'mode': mode.name,
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RecentRoute.fromJson(Map<String, dynamic> json) => RecentRoute(
    start: Place.fromJson(json['start'] as Map<String, dynamic>),
    destination: Place.fromJson(json['destination'] as Map<String, dynamic>),
    mode: TravelMode.values.byName(json['mode'] as String),
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String encode() => jsonEncode(toJson());
}

LatLng _coordinateFromJson(dynamic coordinate) {
  if (coordinate is! List<dynamic> || coordinate.length < 2) {
    throw const FormatException('Invalid coordinate');
  }
  final longitude = (coordinate[0] as num?)?.toDouble();
  final latitude = (coordinate[1] as num?)?.toDouble();
  if (!_validCoordinate(latitude, longitude)) {
    throw const FormatException('Invalid coordinate');
  }
  return LatLng(latitude!, longitude!);
}

bool _validCoordinate(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
