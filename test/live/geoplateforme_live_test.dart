@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/ign_route_map.dart';

import '../support/test_fixtures.dart';

void main() {
  late http.Client client;
  late GeoplateformeApi api;

  setUp(() {
    client = http.Client();
    api = GeoplateformeApi(
      client: client,
      requestTimeout: const Duration(seconds: 20),
    );
  });

  tearDown(() {
    client.close();
  });

  test('completion returns a public Paris location', () async {
    final results = await _retry(
      () => api.searchPlaces('Hôtel de Ville Paris'),
    );

    expect(results, isNotEmpty);
    expect(results.every((place) => place.label.isNotEmpty), isTrue);
  });

  test('car route exposes GeoJSON steps in metropolitan France', () async {
    final route = await _retry(
      () => api.calculateRoute(
        start: parisStart,
        destination: parisDestination,
        mode: TravelMode.car,
      ),
    );

    _expectValidRoute(route);
  });

  test('pedestrian route is available in La Réunion', () async {
    final route = await _retry(
      () => api.calculateRoute(
        start: reunionStart,
        destination: reunionDestination,
        mode: TravelMode.pedestrian,
      ),
    );

    _expectValidRoute(route);
  });

  test('Plan IGN WMTS serves an image tile', () async {
    final uri = Uri.parse(
      ignPlanWmtsUrl
          .replaceFirst('{z}', '0')
          .replaceFirst('{y}', '0')
          .replaceFirst('{x}', '0'),
    );

    final response = await _retry(() => client.get(uri));

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('image'));
    expect(response.bodyBytes, isNotEmpty);
  });
}

void _expectValidRoute(RoutePlan route) {
  expect(route.points.length, greaterThan(1));
  expect(route.distanceMeters, greaterThan(0));
  expect(route.durationSeconds, greaterThan(0));
  expect(route.steps, isNotEmpty);
  expect(route.resourceVersion, isNotEmpty);
}

Future<T> _retry<T>(Future<T> Function() action) async {
  Object? lastError;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }
  throw lastError!;
}
