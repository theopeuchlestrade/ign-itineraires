import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesRouteStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SharedPreferencesRouteStore();
  });

  test('route history is disabled by default', () async {
    expect(await store.loadHistoryEnabled(), isFalse);
  });

  test('persists the history choice and can erase recent routes', () async {
    final route = RecentRoute(
      start: const Place(label: 'A', latitude: 48, longitude: 2),
      destination: const Place(label: 'B', latitude: 49, longitude: 3),
      mode: TravelMode.car,
      distanceMeters: 1000,
      durationSeconds: 600,
      createdAt: DateTime.utc(2026),
    );

    await store.saveHistoryEnabled(true);
    await store.saveRecents([route]);

    expect(await store.loadHistoryEnabled(), isTrue);
    expect(await store.loadRecents(), hasLength(1));

    await store.clearRecents();

    expect(await store.loadRecents(), isEmpty);
  });

  test('ignores corrupted local entries without losing valid ones', () async {
    final favorite = const Place(label: 'A', latitude: 48, longitude: 2);
    final recent = RecentRoute(
      start: favorite,
      destination: const Place(label: 'B', latitude: 49, longitude: 3),
      mode: TravelMode.pedestrian,
      distanceMeters: 1200,
      durationSeconds: 900,
      createdAt: DateTime.utc(2026),
    );
    SharedPreferences.setMockInitialValues({
      'favorite_places_v1': [
        jsonEncode(favorite.toJson()),
        jsonEncode({'label': 'Broken', 'latitude': 'north', 'longitude': 2}),
        jsonEncode({'label': 'Out of range', 'latitude': 999, 'longitude': 2}),
        '{not-json',
      ],
      'recent_routes_v1': [
        jsonEncode(recent.toJson()),
        jsonEncode({...recent.toJson(), 'mode': 'spaceship'}),
        jsonEncode({...recent.toJson(), 'distanceMeters': -1}),
        '[]',
      ],
    });
    store = SharedPreferencesRouteStore();

    final favorites = await store.loadFavorites();
    final recents = await store.loadRecents();

    expect(favorites, [favorite]);
    expect(recents, hasLength(1));
    expect(recents.single.destination.label, recent.destination.label);
    expect(recents.single.mode, recent.mode);
  });
}
