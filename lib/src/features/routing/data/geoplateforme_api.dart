import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/network_endpoints.dart';

abstract interface class GeoplateformeGateway {
  Future<List<Place>> searchPlaces(String query);

  Future<RoutePlan> calculateRoute({
    required Place start,
    required Place destination,
    required TravelMode mode,
  });
}

enum GeoplateformeFailureKind {
  searchUnavailable,
  noRoute,
  rateLimited,
  serviceUnavailable,
  timeout,
  offline,
  invalidResponse,
}

class GeoplateformeException implements Exception {
  const GeoplateformeException(
    this.message, {
    this.kind = GeoplateformeFailureKind.serviceUnavailable,
    this.retryAfter,
  });

  final String message;
  final GeoplateformeFailureKind kind;
  final Duration? retryAfter;

  bool get isRetryable => switch (kind) {
    GeoplateformeFailureKind.noRoute ||
    GeoplateformeFailureKind.invalidResponse => false,
    _ => true,
  };

  @override
  String toString() => message;
}

class GeoplateformeApi implements GeoplateformeGateway {
  GeoplateformeApi({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;
  static const _host = NetworkEndpoints.geoplateformeHost;

  @override
  Future<List<Place>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final parameters = <String, String>{
      'text': trimmed,
      'maximumResponses': '6',
    };
    final uri = Uri.https(_host, '/geocodage/completion/', parameters);
    final response = await _get(uri);
    final body = _decodeObject(response);
    if (body['status'] != 'OK') {
      throw const GeoplateformeException(
        'La recherche d’adresse est momentanément indisponible.',
        kind: GeoplateformeFailureKind.searchUnavailable,
      );
    }

    try {
      return (body['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Place.fromCompletionJson)
          .toList(growable: false);
    } on FormatException {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
        kind: GeoplateformeFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<RoutePlan> calculateRoute({
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) async {
    final uri = Uri.https(_host, '/navigation/itineraire');
    final response = await _post(uri, {
      'resource': 'bdtopo-osrm',
      'start': '${start.longitude},${start.latitude}',
      'end': '${destination.longitude},${destination.latitude}',
      'profile': mode.apiValue,
      'optimization': 'fastest',
      'geometryFormat': 'geojson',
      'getSteps': 'true',
      'getBbox': 'true',
      'distanceUnit': 'meter',
      'timeUnit': 'second',
      'crs': 'EPSG:4326',
    });
    try {
      final route = await compute(
        _parseRouteResponse,
        response.bodyBytes,
        debugLabel: 'parse-geoplateforme-route',
      );
      if (route == null) {
        throw const GeoplateformeException(
          'Aucun itinéraire n’a été trouvé entre ces deux points.',
          kind: GeoplateformeFailureKind.noRoute,
        );
      }
      return route;
    } on FormatException {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
        kind: GeoplateformeFailureKind.invalidResponse,
      );
    } on TypeError {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
        kind: GeoplateformeFailureKind.invalidResponse,
      );
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<http.Response> _get(Uri uri) async {
    return _send(
      () => _client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ign-itineraires/1.0',
        },
      ),
    );
  }

  Future<http.Response> _post(Uri uri, Map<String, String> parameters) async {
    return _send(
      () => _client.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'ign-itineraires/1.0',
        },
        body: jsonEncode(parameters),
      ),
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(requestTimeout);
      if (response.statusCode == 429) {
        final seconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 5;
        throw GeoplateformeException(
          'Trop de demandes. Réessayez dans quelques secondes.',
          kind: GeoplateformeFailureKind.rateLimited,
          retryAfter: Duration(seconds: seconds),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const GeoplateformeException(
          'Le service cartes.gouv.fr ne répond pas correctement.',
          kind: GeoplateformeFailureKind.serviceUnavailable,
        );
      }
      return response;
    } on TimeoutException {
      throw const GeoplateformeException(
        'Le service cartes.gouv.fr met trop de temps à répondre.',
        kind: GeoplateformeFailureKind.timeout,
      );
    } on http.ClientException {
      throw const GeoplateformeException(
        'Connexion impossible. Vérifiez votre accès à Internet.',
        kind: GeoplateformeFailureKind.offline,
      );
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return decoded;
    } on FormatException catch (_) {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
        kind: GeoplateformeFailureKind.invalidResponse,
      );
    }
  }
}

RoutePlan? _parseRouteResponse(Uint8List bodyBytes) {
  final decoded = jsonDecode(utf8.decode(bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  if (decoded['geometry'] == null) return null;
  return RoutePlan.fromJson(decoded);
}
