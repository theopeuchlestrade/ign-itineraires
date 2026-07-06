import 'package:flutter/foundation.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
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
  int _locationGeneration = 0;
  int _calculationGeneration = 0;

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
    notifyListeners();
    await useCurrentLocation(silent: true);
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
    notifyListeners();
  }

  void setDestination(Place? place) {
    _calculationGeneration++;
    calculating = false;
    destination = place;
    route = null;
    clearMessage();
    notifyListeners();
  }

  void setMode(TravelMode value) {
    if (mode == value) return;
    mode = value;
    _calculationGeneration++;
    calculating = false;
    route = null;
    clearMessage();
    notifyListeners();
  }

  Future<void> useCurrentLocation({bool silent = false}) async {
    final generation = ++_locationGeneration;
    locating = true;
    if (!silent) clearMessage();
    notifyListeners();
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
      if (!silent) _showError(error.message);
    } finally {
      if (generation == _locationGeneration) {
        locating = false;
        notifyListeners();
      }
    }
  }

  Future<void> calculate() async {
    final generation = ++_calculationGeneration;
    final selectedStart = start;
    final selectedDestination = destination;
    if (selectedStart == null || selectedDestination == null) {
      _showError('Choisissez un départ et une arrivée.');
      notifyListeners();
      return;
    }

    calculating = true;
    route = null;
    clearMessage();
    notifyListeners();
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
        recents = [
          recent,
          ...recents.where(
            (item) =>
                item.start != selectedStart ||
                item.destination != selectedDestination ||
                item.mode != mode,
          ),
        ].take(10).toList(growable: false);
        await _store.saveRecents(recents);
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
        notifyListeners();
      }
    }
  }

  Future<void> toggleDestinationFavorite() async {
    final place = destination;
    if (place == null) return;
    if (favorites.contains(place)) {
      favorites = favorites.where((item) => item != place).toList();
      _showMessage('Favori supprimé.');
    } else {
      favorites = [place, ...favorites].take(20).toList(growable: false);
      _showMessage('Destination ajoutée aux favoris.');
    }
    notifyListeners();
    await _store.saveFavorites(favorites);
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
    notifyListeners();
  }

  Future<void> setHistoryEnabled(bool enabled) async {
    if (historyEnabled == enabled) return;
    historyEnabled = enabled;
    if (!enabled) {
      recents = const [];
      await _store.clearRecents();
    }
    notifyListeners();
    await _store.saveHistoryEnabled(enabled);
  }

  Future<void> clearRecents() async {
    recents = const [];
    notifyListeners();
    await _store.clearRecents();
  }

  void clearMessage() {
    message = null;
    messageIsError = false;
  }

  void _showError(String value) {
    message = value;
    messageIsError = true;
  }

  void _showMessage(String value) {
    message = value;
    messageIsError = false;
  }
}
