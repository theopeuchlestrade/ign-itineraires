import 'package:flutter/foundation.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

class RoutingController extends ChangeNotifier {
  RoutingController(this._api, this._location, this._store);

  final GeoplateformeGateway _api;
  final DeviceLocationGateway _location;
  final LocalRouteStore _store;

  Place? start;
  Place? destination;
  TravelMode mode = TravelMode.car;
  RoutePlan? route;
  List<Place> favorites = const [];
  List<RecentRoute> recents = const [];
  bool historyEnabled = false;
  bool locating = false;
  bool calculating = false;
  String? message;
  bool messageIsError = false;
  LocationRecovery? locationRecovery;
  int _locationGeneration = 0;
  int _calculationGeneration = 0;
  bool _disposed = false;

  bool get canCalculate => start != null && destination != null && !calculating;

  bool get destinationIsFavorite =>
      destination != null && favorites.contains(destination);

  Future<void> initialize() async {
    try {
      final loaded = await Future.wait([
        _store.loadFavorites(),
        _store.loadRecents(),
        _store.loadHistoryEnabled(),
      ]);
      favorites = loaded[0] as List<Place>;
      historyEnabled = loaded[2] as bool;
      recents = historyEnabled ? loaded[1] as List<RecentRoute> : const [];
      if (!historyEnabled && (loaded[1] as List<RecentRoute>).isNotEmpty) {
        await _store.clearRecents();
      }
    } catch (_) {
      favorites = const [];
      recents = const [];
      historyEnabled = false;
    }
    _notify();
  }

  Future<List<Place>> search(String query) {
    return _api.searchPlaces(query);
  }

  void setStart(Place? place) {
    _locationGeneration++;
    _calculationGeneration++;
    calculating = false;
    start = place;
    route = null;
    clearMessage();
    _notify();
  }

  void setDestination(Place? place) {
    _calculationGeneration++;
    calculating = false;
    destination = place;
    route = null;
    clearMessage();
    _notify();
  }

  void setMode(TravelMode value) {
    if (mode == value) return;
    mode = value;
    _calculationGeneration++;
    calculating = false;
    route = null;
    clearMessage();
    _notify();
  }

  Future<void> useCurrentLocation({bool silent = false}) async {
    final generation = ++_locationGeneration;
    locating = true;
    if (!silent) clearMessage();
    _notify();
    try {
      final current = await _location.currentPlace();
      if (generation != _locationGeneration) return;
      start = current;
      route = null;
      if (!silent) {
        _showMessage('Position actuelle utilisée comme départ.');
      }
    } on DeviceLocationException catch (error) {
      if (generation != _locationGeneration) return;
      if (!silent) {
        locationRecovery = error.recovery;
        _showError(error.message);
      }
    } finally {
      if (generation == _locationGeneration) {
        locating = false;
        _notify();
      }
    }
  }

  Future<void> recoverLocation() async {
    final recovery = locationRecovery;
    if (recovery == null) return;
    final opened = switch (recovery) {
      LocationRecovery.openLocationSettings =>
        await _location.openLocationSettings(),
      LocationRecovery.openAppSettings => await _location.openAppSettings(),
    };
    if (opened) {
      locationRecovery = null;
      _showMessage(
        'Revenez dans l’application après avoir modifié les réglages.',
      );
    } else {
      _showError('Impossible d’ouvrir les réglages de localisation.');
    }
    _notify();
  }

  Future<void> calculate() async {
    final generation = ++_calculationGeneration;
    final selectedStart = start;
    final selectedDestination = destination;
    if (selectedStart == null || selectedDestination == null) {
      _showError('Choisissez un départ et une arrivée.');
      _notify();
      return;
    }

    calculating = true;
    route = null;
    clearMessage();
    _notify();
    try {
      final result = await _api.calculateRoute(
        start: selectedStart,
        destination: selectedDestination,
        mode: mode,
      );
      if (generation != _calculationGeneration) return;
      route = result;
      if (historyEnabled) {
        final recent = RecentRoute(
          start: selectedStart,
          destination: selectedDestination,
          mode: mode,
          distanceMeters: result.distanceMeters,
          durationSeconds: result.durationSeconds,
          createdAt: DateTime.now(),
        );
        final updatedRecents = [
          recent,
          ...recents.where(
            (item) =>
                item.start != selectedStart ||
                item.destination != selectedDestination ||
                item.mode != mode,
          ),
        ].take(10).toList(growable: false);
        try {
          await _store.saveRecents(updatedRecents);
          recents = updatedRecents;
        } catch (_) {
          _showMessage(
            'Itinéraire calculé, mais l’historique n’a pas pu être enregistré.',
          );
        }
      }
    } on GeoplateformeException catch (error) {
      if (generation != _calculationGeneration) return;
      _showError(error.message);
    } catch (_) {
      if (generation != _calculationGeneration) return;
      _showError('L’itinéraire n’a pas pu être calculé.');
    } finally {
      if (generation == _calculationGeneration) {
        calculating = false;
        _notify();
      }
    }
  }

  Future<void> toggleDestinationFavorite() async {
    final place = destination;
    if (place == null) return;
    final previous = favorites;
    if (previous.contains(place)) {
      favorites = previous.where((item) => item != place).toList();
      _showMessage('Favori supprimé.');
    } else {
      favorites = [place, ...previous].take(20).toList(growable: false);
      _showMessage('Destination ajoutée aux favoris.');
    }
    _notify();
    try {
      await _store.saveFavorites(favorites);
    } catch (_) {
      favorites = previous;
      _showError('Le favori n’a pas pu être enregistré.');
      _notify();
    }
  }

  void restoreRecent(RecentRoute recent) {
    _locationGeneration++;
    _calculationGeneration++;
    locating = false;
    calculating = false;
    start = recent.start;
    destination = recent.destination;
    mode = recent.mode;
    route = null;
    clearMessage();
    _notify();
  }

  Future<void> setHistoryEnabled(bool enabled) async {
    if (historyEnabled == enabled) return;
    try {
      if (!enabled) await _store.clearRecents();
      await _store.saveHistoryEnabled(enabled);
    } catch (_) {
      _showError('La préférence d’historique n’a pas pu être enregistrée.');
      _notify();
      return;
    }
    historyEnabled = enabled;
    if (!enabled) recents = const [];
    _notify();
  }

  Future<void> clearRecents() async {
    try {
      await _store.clearRecents();
      recents = const [];
      _notify();
    } catch (_) {
      _showError('L’historique n’a pas pu être effacé.');
      _notify();
    }
  }

  void clearMessage() {
    message = null;
    messageIsError = false;
    locationRecovery = null;
  }

  void _showError(String value) {
    message = value;
    messageIsError = true;
  }

  void _showMessage(String value) {
    message = value;
    messageIsError = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _locationGeneration++;
    _calculationGeneration++;
    super.dispose();
  }
}
