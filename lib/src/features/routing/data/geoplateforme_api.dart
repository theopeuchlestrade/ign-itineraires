import 'dart:async';
import 'dart:convert';

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

class GeoplateformeException implements Exception {
  const GeoplateformeException(this.message, {this.retryAfter});

  final String message;
  final Duration? retryAfter;

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
    final body = _decodeObject(response);
    if (body['geometry'] == null) {
      throw const GeoplateformeException(
        'Aucun itinéraire n’a été trouvé entre ces deux points.',
      );
    }
    try {
      return RoutePlan.fromJson(body);
    } on FormatException {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
      );
    } on TypeError {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
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
          retryAfter: Duration(seconds: seconds),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const GeoplateformeException(
          'Le service cartes.gouv.fr ne répond pas correctement.',
        );
      }
      return response;
    } on TimeoutException {
      throw const GeoplateformeException(
        'Le service cartes.gouv.fr met trop de temps à répondre.',
      );
    } on http.ClientException {
      throw const GeoplateformeException(
        'Connexion impossible. Vérifiez votre accès à Internet.',
      );
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on FormatException {
      throw const GeoplateformeException(
        'Réponse inattendue du service cartes.gouv.fr.',
      );
    }
  }
}
