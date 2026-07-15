import 'dart:convert';

import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalRouteStore {
  Future<List<Place>> loadFavorites();

  Future<void> saveFavorites(List<Place> favorites);

  Future<List<RecentRoute>> loadRecents();

  Future<void> saveRecents(List<RecentRoute> recents);

  Future<bool> loadHistoryEnabled();

  Future<void> saveHistoryEnabled(bool enabled);

  Future<void> clearRecents();

  Future<bool> loadVoiceEnabled();

  Future<void> saveVoiceEnabled(bool enabled);
}

class LocalStoreException implements Exception {
  const LocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SharedPreferencesRouteStore implements LocalRouteStore {
  static const _favoritesKey = 'favorite_places_v1';
  static const _recentsKey = 'recent_routes_v1';
  static const _historyEnabledKey = 'route_history_enabled_v1';
  static const _voiceEnabledKey = 'navigation_voice_enabled_v1';

  @override
  Future<List<Place>> loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeItems(
      preferences.getStringList(_favoritesKey),
      Place.fromJson,
    ).toList(growable: false);
  }

  @override
  Future<void> saveFavorites(List<Place> favorites) async {
    final preferences = await SharedPreferences.getInstance();
    _requireSaved(
      await preferences.setStringList(
        _favoritesKey,
        favorites.map((place) => jsonEncode(place.toJson())).toList(),
      ),
    );
  }

  @override
  Future<List<RecentRoute>> loadRecents() async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeItems(
      preferences.getStringList(_recentsKey),
      RecentRoute.fromJson,
    ).toList(growable: false);
  }

  @override
  Future<void> saveRecents(List<RecentRoute> recents) async {
    final preferences = await SharedPreferences.getInstance();
    _requireSaved(
      await preferences.setStringList(
        _recentsKey,
        recents.map((route) => route.encode()).toList(),
      ),
    );
  }

  @override
  Future<bool> loadHistoryEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_historyEnabledKey) ?? false;
  }

  @override
  Future<void> saveHistoryEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    _requireSaved(await preferences.setBool(_historyEnabledKey, enabled));
  }

  @override
  Future<void> clearRecents() async {
    final preferences = await SharedPreferences.getInstance();
    _requireSaved(await preferences.remove(_recentsKey));
  }

  @override
  Future<bool> loadVoiceEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_voiceEnabledKey) ?? true;
  }

  @override
  Future<void> saveVoiceEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    _requireSaved(await preferences.setBool(_voiceEnabledKey, enabled));
  }

  Iterable<T> _decodeItems<T>(
    List<String>? values,
    T Function(Map<String, dynamic> json) decode,
  ) sync* {
    for (final value in values ?? const <String>[]) {
      try {
        final json = jsonDecode(value);
        if (json is! Map<String, dynamic>) continue;
        yield decode(json);
      } on FormatException {
        // Ignore obsolete or corrupted local entries.
      } on TypeError {
        // Ignore obsolete or corrupted local entries.
      } on ArgumentError {
        // Ignore obsolete or corrupted local entries.
      }
    }
  }

  void _requireSaved(bool saved) {
    if (!saved) {
      throw const LocalStoreException(
        'Les données locales n’ont pas pu être enregistrées.',
      );
    }
  }
}
