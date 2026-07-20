import 'dart:async';

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

  Place? _start;
  Place? _destination;
  TravelMode _mode = TravelMode.car;
  RoutePlan? _route;
  List<Place> _favorites = const [];
  List<RecentRoute> _recents = const [];
  bool _historyEnabled = false;
  bool _locating = false;
  bool _calculating = false;
  bool _favoriteMutationInProgress = false;
  bool _historyMutationInProgress = false;
  String? _message;
  bool _messageIsError = false;
  LocationRecovery? _locationRecovery;
  bool _routeRetryAvailable = false;
  int _retrySecondsRemaining = 0;
  int _locationGeneration = 0;
  int _calculationGeneration = 0;
  Timer? _retryTimer;
  bool _disposed = false;

  Place? get start => _start;
  Place? get destination => _destination;
  TravelMode get mode => _mode;
  RoutePlan? get route => _route;
  List<Place> get favorites => _favorites;
  List<RecentRoute> get recents => _recents;
  bool get historyEnabled => _historyEnabled;
  bool get locating => _locating;
  bool get calculating => _calculating;
  bool get favoriteMutationInProgress => _favoriteMutationInProgress;
  bool get historyMutationInProgress => _historyMutationInProgress;
  String? get message => _message;
  bool get messageIsError => _messageIsError;
  LocationRecovery? get locationRecovery => _locationRecovery;
  bool get routeRetryAvailable => _routeRetryAvailable;
  int get retrySecondsRemaining => _retrySecondsRemaining;

  bool get canCalculate =>
      start != null &&
      destination != null &&
      !calculating &&
      retrySecondsRemaining == 0;

  bool get canRetryRoute =>
      routeRetryAvailable && retrySecondsRemaining == 0 && canCalculate;

  String get routeRetryLabel => retrySecondsRemaining > 0
      ? 'Réessayer dans $retrySecondsRemaining s'
      : 'Réessayer';

  bool get destinationIsFavorite =>
      destination != null && favorites.contains(destination);

  Future<void> initialize() async {
    try {
      final loaded = await Future.wait([
        _store.loadFavorites(),
        _store.loadRecents(),
        _store.loadHistoryEnabled(),
      ]);
      _favorites = List<Place>.unmodifiable(loaded[0] as List<Place>);
      _historyEnabled = loaded[2] as bool;
      _recents = historyEnabled
          ? List<RecentRoute>.unmodifiable(loaded[1] as List<RecentRoute>)
          : const [];
      if (!historyEnabled && (loaded[1] as List<RecentRoute>).isNotEmpty) {
        await _store.clearRecents();
      }
    } catch (_) {
      _favorites = const [];
      _recents = const [];
      _historyEnabled = false;
    }
    _notify();
  }

  Future<List<Place>> search(String query) {
    return _api.searchPlaces(query);
  }

  void setStart(Place? place) {
    _locationGeneration++;
    _calculationGeneration++;
    _calculating = false;
    _start = place;
    _route = null;
    clearMessage();
    _notify();
  }

  void swapEndpoints() {
    if (start == null && destination == null) return;
    _locationGeneration++;
    _calculationGeneration++;
    _locating = false;
    _calculating = false;
    final previousStart = start;
    _start = destination;
    _destination = previousStart;
    _route = null;
    clearMessage();
    _notify();
  }

  void setDestination(Place? place) {
    _calculationGeneration++;
    _calculating = false;
    _destination = place;
    _route = null;
    clearMessage();
    _notify();
  }

  void setMode(TravelMode value) {
    if (mode == value) return;
    _mode = value;
    _calculationGeneration++;
    _calculating = false;
    _route = null;
    clearMessage();
    _notify();
  }

  Future<void> useCurrentLocation({bool silent = false}) async {
    final generation = ++_locationGeneration;
    _locating = true;
    if (!silent) clearMessage();
    _notify();
    try {
      final current = await _location.currentPlace();
      if (generation != _locationGeneration) return;
      _start = current;
      _route = null;
      if (!silent) {
        _showMessage('Position actuelle utilisée comme départ.');
      }
    } on DeviceLocationException catch (error) {
      if (generation != _locationGeneration) return;
      if (!silent) {
        _locationRecovery = error.recovery;
        _showError(error.message);
      }
    } finally {
      if (generation == _locationGeneration) {
        _locating = false;
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
      _locationRecovery = null;
      _showMessage(
        'Revenez dans l’application après avoir modifié les réglages.',
      );
    } else {
      _showError('Impossible d’ouvrir les réglages de localisation.');
    }
    _notify();
  }

  Future<void> calculate() async {
    if (retrySecondsRemaining > 0) {
      _showError(
        'Le service demande de patienter encore $retrySecondsRemaining s.',
      );
      _notify();
      return;
    }
    final generation = ++_calculationGeneration;
    final selectedStart = start;
    final selectedDestination = destination;
    if (selectedStart == null || selectedDestination == null) {
      _showError('Choisissez un départ et une arrivée.');
      _notify();
      return;
    }

    _calculating = true;
    _route = null;
    clearMessage();
    _notify();
    try {
      final result = await _api.calculateRoute(
        start: selectedStart,
        destination: selectedDestination,
        mode: mode,
      );
      if (generation != _calculationGeneration) return;
      _route = result;
      _clearRouteRetry();
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
          _recents = updatedRecents;
        } catch (_) {
          _showMessage(
            'Itinéraire calculé, mais l’historique n’a pas pu être enregistré.',
          );
        }
      }
    } on GeoplateformeException catch (error) {
      if (generation != _calculationGeneration) return;
      _handleRouteFailure(error);
    } catch (_) {
      if (generation != _calculationGeneration) return;
      _showError('L’itinéraire n’a pas pu être calculé.');
      _routeRetryAvailable = true;
    } finally {
      if (generation == _calculationGeneration) {
        _calculating = false;
        _notify();
      }
    }
  }

  Future<void> toggleDestinationFavorite() async {
    final place = destination;
    if (place == null || favoriteMutationInProgress) return;
    _favoriteMutationInProgress = true;
    final previous = favorites;
    if (previous.contains(place)) {
      _favorites = previous.where((item) => item != place).toList();
      _showMessage('Favori supprimé.');
    } else {
      _favorites = [place, ...previous].take(20).toList(growable: false);
      _showMessage('Destination ajoutée aux favoris.');
    }
    _notify();
    try {
      await _store.saveFavorites(favorites);
    } catch (_) {
      _favorites = previous;
      _showError('Le favori n’a pas pu être enregistré.');
    } finally {
      _favoriteMutationInProgress = false;
      _notify();
    }
  }

  void restoreRecent(RecentRoute recent) {
    _locationGeneration++;
    _calculationGeneration++;
    _locating = false;
    _calculating = false;
    _start = recent.start;
    _destination = recent.destination;
    _mode = recent.mode;
    _route = null;
    clearMessage();
    _notify();
  }

  Future<void> setHistoryEnabled(bool enabled) async {
    if (historyEnabled == enabled || historyMutationInProgress) return;
    _historyMutationInProgress = true;
    _notify();
    try {
      if (!enabled) await _store.clearRecents();
      await _store.saveHistoryEnabled(enabled);
      _historyEnabled = enabled;
      if (!enabled) _recents = const [];
    } catch (_) {
      _showError('La préférence d’historique n’a pas pu être enregistrée.');
      return;
    } finally {
      _historyMutationInProgress = false;
      _notify();
    }
  }

  Future<void> clearRecents() async {
    if (historyMutationInProgress) return;
    _historyMutationInProgress = true;
    _notify();
    try {
      await _store.clearRecents();
      _recents = const [];
    } catch (_) {
      _showError('L’historique n’a pas pu être effacé.');
    } finally {
      _historyMutationInProgress = false;
      _notify();
    }
  }

  void clearMessage() {
    _message = null;
    _messageIsError = false;
    _locationRecovery = null;
    _clearRouteRetry();
  }

  void _handleRouteFailure(GeoplateformeException error) {
    _showError(error.message);
    _routeRetryAvailable = error.isRetryable;
    final retryAfter = error.retryAfter;
    if (!routeRetryAvailable || retryAfter == null) return;
    _retrySecondsRemaining = retryAfter.inSeconds.clamp(0, 300).toInt();
    if (retrySecondsRemaining == 0) return;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _retrySecondsRemaining--;
      if (retrySecondsRemaining <= 0) {
        _retrySecondsRemaining = 0;
        timer.cancel();
        _retryTimer = null;
      }
      _notify();
    });
  }

  void _clearRouteRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _routeRetryAvailable = false;
    _retrySecondsRemaining = 0;
  }

  void _showError(String value) {
    _message = value;
    _messageIsError = true;
  }

  void _showMessage(String value) {
    _message = value;
    _messageIsError = false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _locationGeneration++;
    _calculationGeneration++;
    super.dispose();
  }
}
