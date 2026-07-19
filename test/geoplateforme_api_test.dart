import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

void main() {
  test('searches places with the official completion contract', () async {
    final api = GeoplateformeApi(
      client: MockClient((request) async {
        expect(request.url.path, '/geocodage/completion/');
        expect(request.url.queryParameters['text'], 'rue de la paix');
        expect(request.url.queryParameters.containsKey('lonlat'), isFalse);
        return http.Response(
          '{"status":"OK","results":[{"x":2.33,"y":48.86,'
          '"fulltext":"Rue de la Paix, Paris"}]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final results = await api.searchPlaces('rue de la paix');

    expect(results, hasLength(1));
    expect(results.single.label, 'Rue de la Paix, Paris');
  });

  test(
    'does not call completion for a query shorter than three characters',
    () async {
      var calls = 0;
      final api = GeoplateformeApi(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(await api.searchPlaces('ab'), isEmpty);
      expect(calls, 0);
    },
  );

  test('sends route coordinates in a POST body instead of the URL', () async {
    final api = GeoplateformeApi(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/navigation/itineraire');
        expect(request.url.query, isEmpty);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['start'], '2.0,48.0');
        expect(body['end'], '3.0,49.0');
        expect(body['profile'], 'pedestrian');
        return http.Response(
          '{"geometry":{"type":"LineString","coordinates":'
          '[[2.0,48.0],[3.0,49.0]]},"distance":1000,"duration":600}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final route = await api.calculateRoute(
      start: const Place(label: 'A', latitude: 48, longitude: 2),
      destination: const Place(label: 'B', latitude: 49, longitude: 3),
      mode: TravelMode.pedestrian,
    );

    expect(route.distanceMeters, 1000);
  });

  test('maps a 429 response to a useful domain exception', () async {
    final api = GeoplateformeApi(
      client: MockClient(
        (_) async => http.Response('', 429, headers: {'retry-after': '4'}),
      ),
    );

    expect(
      () => api.calculateRoute(
        start: const Place(label: 'A', latitude: 48, longitude: 2),
        destination: const Place(label: 'B', latitude: 49, longitude: 3),
        mode: TravelMode.car,
      ),
      throwsA(
        isA<GeoplateformeException>()
            .having(
              (error) => error.kind,
              'kind',
              GeoplateformeFailureKind.rateLimited,
            )
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 4),
            ),
      ),
    );
  });

  test('maps server failures to a stable domain message', () async {
    final api = GeoplateformeApi(
      client: MockClient((_) async => http.Response('maintenance', 503)),
    );

    expect(
      () => api.searchPlaces('Paris'),
      throwsA(
        isA<GeoplateformeException>().having(
          (error) => error.message,
          'message',
          'Le service cartes.gouv.fr ne répond pas correctement.',
        ),
      ),
    );
  });

  test('rejects malformed JSON responses', () async {
    final api = GeoplateformeApi(
      client: MockClient((_) async => http.Response('not-json', 200)),
    );

    expect(
      () => api.searchPlaces('Paris'),
      throwsA(
        isA<GeoplateformeException>().having(
          (error) => error.message,
          'message',
          'Réponse inattendue du service cartes.gouv.fr.',
        ),
      ),
    );
  });

  test('rejects a valid JSON response whose root is not an object', () async {
    final api = GeoplateformeApi(
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    expect(
      () => api.searchPlaces('Paris'),
      throwsA(isA<GeoplateformeException>()),
    );
  });

  test('turns request timeouts into a useful message', () async {
    final pending = Completer<http.Response>();
    final api = GeoplateformeApi(
      client: MockClient((_) => pending.future),
      requestTimeout: const Duration(milliseconds: 1),
    );

    expect(
      () => api.searchPlaces('Paris'),
      throwsA(
        isA<GeoplateformeException>().having(
          (error) => error.message,
          'message',
          'Le service cartes.gouv.fr met trop de temps à répondre.',
        ),
      ),
    );
  });

  test('accepts route steps with missing optional geometry', () async {
    final api = GeoplateformeApi(
      client: MockClient(
        (_) async => http.Response(
          '{"geometry":{"type":"LineString","coordinates":'
          '[[2.0,48.0],[3.0,49.0]]},"distance":1000,"duration":600,'
          '"portions":[{"steps":[{"distance":100,'
          '"instruction":{"type":"continue","modifier":"straight"}}]}]}',
          200,
        ),
      ),
    );

    final route = await api.calculateRoute(
      start: const Place(label: 'A', latitude: 48, longitude: 2),
      destination: const Place(label: 'B', latitude: 49, longitude: 3),
      mode: TravelMode.car,
    );

    expect(route.steps.single.points, isEmpty);
    expect(route.steps.single.instruction, 'Continuez tout droit');
  });

  test('rejects unsuccessful completion payloads', () async {
    final api = GeoplateformeApi(
      client: MockClient((_) async => http.Response('{"status":"ERROR"}', 200)),
    );

    expect(
      () => api.searchPlaces('Paris'),
      throwsA(
        isA<GeoplateformeException>().having(
          (error) => error.message,
          'message',
          contains('recherche d’adresse'),
        ),
      ),
    );
  });

  test('reports when no route geometry is returned', () async {
    final api = GeoplateformeApi(
      client: MockClient(
        (_) async => http.Response('{"distance":0,"duration":0}', 200),
      ),
    );

    expect(
      () => api.calculateRoute(
        start: const Place(label: 'A', latitude: 48, longitude: 2),
        destination: const Place(label: 'B', latitude: 49, longitude: 3),
        mode: TravelMode.car,
      ),
      throwsA(
        isA<GeoplateformeException>().having(
          (error) => error.message,
          'message',
          contains('Aucun itinéraire'),
        ),
      ),
    );
  });

  test('maps low-level client failures to an offline message', () async {
    final api = GeoplateformeApi(
      client: MockClient((request) => throw http.ClientException('offline')),
    );

    expect(
      () => api.searchPlaces('Paris'),
      throwsA(
        isA<GeoplateformeException>()
            .having(
              (error) => error.kind,
              'kind',
              GeoplateformeFailureKind.offline,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Connexion impossible'),
            ),
      ),
    );
  });

  test('rejects invalid route coordinates and metrics', () async {
    final api = GeoplateformeApi(
      client: MockClient(
        (_) async => http.Response(
          '{"geometry":{"type":"LineString","coordinates":'
          '[[2.0,48.0],[999.0,49.0]]},"distance":-1,"duration":600}',
          200,
        ),
      ),
    );

    expect(
      () => api.calculateRoute(
        start: const Place(label: 'A', latitude: 48, longitude: 2),
        destination: const Place(label: 'B', latitude: 49, longitude: 3),
        mode: TravelMode.car,
      ),
      throwsA(
        isA<GeoplateformeException>().having(
          (error) => error.message,
          'message',
          contains('Réponse inattendue'),
        ),
      ),
    );
  });
}
