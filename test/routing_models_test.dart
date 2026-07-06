import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

void main() {
  group('Place', () {
    test('parses a Géoplateforme completion result', () {
      final place = Place.fromCompletionJson({
        'x': 2.33115,
        'y': 48.868989,
        'fulltext': '10 Rue de la Paix, 75002 Paris',
      });

      expect(place.label, '10 Rue de la Paix, 75002 Paris');
      expect(place.longitude, 2.33115);
      expect(place.latitude, 48.868989);
    });
  });

  group('RoutePlan', () {
    test('parses GeoJSON coordinates and route steps', () {
      final route = RoutePlan.fromJson({
        'resourceVersion': '2026-06-26',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [2.33, 48.86],
            [2.34, 48.85],
          ],
        },
        'distance': 1450.0,
        'duration': 900.0,
        'portions': [
          {
            'steps': [
              {
                'distance': 120.0,
                'instruction': {'type': 'turn', 'modifier': 'left'},
                'attributes': {
                  'name': {'nom_1_gauche': 'R DE LA PAIX', 'nom_1_droite': ''},
                },
              },
            ],
          },
        ],
      });

      expect(route.points.first.latitude, 48.86);
      expect(route.points.first.longitude, 2.33);
      expect(route.formattedDistance, '1.4 km');
      expect(route.formattedDuration, '15 min');
      expect(
        route.steps.single.instruction,
        'Tournez à gauche sur R DE LA PAIX',
      );
      expect(route.steps.single.points, isEmpty);
    });

    test('preserves each IGN step geometry', () {
      final step = RouteStep.fromJson({
        'distance': 20,
        'instruction': {'type': 'continue', 'modifier': 'straight'},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [2.3, 48.8],
            [2.4, 48.9],
          ],
        },
      });

      expect(step.points, hasLength(2));
      expect(step.points.last.latitude, 48.9);
      expect(step.points.last.longitude, 2.4);
    });
  });

  group('RouteStep instructions', () {
    const cases = <(String, String, String)>[
      ('depart', 'straight', 'Partez tout droit sur RUE TEST'),
      ('turn', 'left', 'Tournez à gauche sur RUE TEST'),
      (
        'fork',
        'slight right',
        'À l’embranchement, continuez légèrement à droite sur RUE TEST',
      ),
      ('roundabout', 'right', 'Au rond-point, continuez à droite sur RUE TEST'),
      ('new name', 'straight', 'Continuez sur RUE TEST'),
      ('arrive', 'left', 'Vous êtes arrivé sur votre gauche'),
    ];

    for (final (type, modifier, instruction) in cases) {
      test('$type/$modifier is translated to French', () {
        final step = RouteStep(
          type: type,
          modifier: modifier,
          roadName: 'RUE TEST',
          distanceMeters: 10,
          points: const [],
        );

        expect(step.instruction, instruction);
      });
    }
  });
}
