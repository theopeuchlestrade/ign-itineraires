import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_engine.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

import 'support/test_fixtures.dart';

void main() {
  const scenarios = <_TraceScenario>[
    _TraceScenario(
      name: 'urban jitter',
      coordinates: [
        (48.85660, 2.35220),
        (48.85662, 2.35320),
        (48.85658, 2.35420),
        (48.85661, 2.35520),
        (48.85660, 2.35620),
      ],
    ),
    _TraceScenario(
      name: 'temporary parallel-road offset',
      coordinates: [
        (48.85660, 2.35220),
        (48.85678, 2.35320),
        (48.85679, 2.35420),
        (48.85660, 2.35520),
        (48.85660, 2.35620),
      ],
    ),
    _TraceScenario(
      name: 'backward fixes after progress',
      coordinates: [
        (48.85660, 2.35420),
        (48.85660, 2.35520),
        (48.85660, 2.35460),
        (48.85660, 2.35410),
        (48.85660, 2.35620),
      ],
    ),
    _TraceScenario(
      name: 'implausible forward jump',
      coordinates: [
        (48.85660, 2.35220),
        (48.85660, 2.35320),
        (48.85690, 2.36220),
      ],
    ),
  ];

  for (final scenario in scenarios) {
    test('${scenario.name} keeps progress monotonic and bounded', () {
      final engine = NavigationEngine(urbanRoute, TravelMode.car);
      var timestamp = DateTime.utc(2026, 1, 1, 12);
      NavigationPosition? previousPosition;
      double? previousProgress;

      for (final (latitude, longitude) in scenario.coordinates) {
        final position = navigationPosition(
          latitude,
          longitude,
          timestamp: timestamp,
        );
        final update = engine.update(
          position,
          previousProgressMeters: previousProgress,
          previousPosition: previousPosition,
        );
        if (previousProgress != null) {
          expect(
            update.progressMeters,
            greaterThanOrEqualTo(previousProgress),
            reason: scenario.name,
          );
          expect(
            update.progressMeters - previousProgress,
            lessThanOrEqualTo(120.01),
            reason: scenario.name,
          );
        }
        previousProgress = update.progressMeters;
        previousPosition = position;
        timestamp = timestamp.add(const Duration(seconds: 1));
      }
    });
  }
}

class _TraceScenario {
  const _TraceScenario({required this.name, required this.coordinates});

  final String name;
  final List<(double, double)> coordinates;
}
