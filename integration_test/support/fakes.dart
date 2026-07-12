import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ign_itineraires/src/app_dependencies.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_launcher.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_services.dart';
import 'package:ign_itineraires/src/features/routing/domain/navigation_models.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

import 'test_fixtures.dart';

class FakeGeoplateforme implements GeoplateformeGateway {
  RoutePlan route = urbanRoute;
  List<Place> searchResults = const [parisStart, parisDestination];
  Object? searchError;
  Object? routeError;
  Completer<RoutePlan>? pendingRoute;
  int searchCalls = 0;
  int routeCalls = 0;
  Place? lastStart;
  Place? lastDestination;
  TravelMode? lastMode;

  @override
  Future<List<Place>> searchPlaces(String query) async {
    searchCalls++;
    final error = searchError;
    if (error != null) throw error;
    final normalized = query.toLowerCase();
    return searchResults
        .where((place) => place.label.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  @override
  Future<RoutePlan> calculateRoute({
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) async {
    routeCalls++;
    lastStart = start;
    lastDestination = destination;
    lastMode = mode;
    final error = routeError;
    if (error != null) throw error;
    final pending = pendingRoute;
    if (pending != null) return pending.future;
    return route;
  }
}

class FakeDeviceLocation implements DeviceLocationGateway {
  FakeDeviceLocation({NavigationPosition? initialPosition})
    : current =
          initialPosition ??
          navigationPosition(parisStart.latitude, parisStart.longitude);

  final StreamController<NavigationPosition> _positions =
      StreamController<NavigationPosition>.broadcast(sync: true);
  NavigationPosition current;
  DeviceLocationException? error;
  int currentPositionCalls = 0;
  int watchCalls = 0;
  int openLocationSettingsCalls = 0;
  int openAppSettingsCalls = 0;
  bool settingsOpenResult = true;

  void emit(NavigationPosition position) {
    current = position;
    _positions.add(position);
  }

  void emitError(Object value) => _positions.addError(value);

  Future<void> close() {
    unawaited(_positions.close());
    return Future.value();
  }

  @override
  Future<Place> currentPlace() async => (await currentPosition()).asPlace;

  @override
  Future<NavigationPosition> currentPosition({
    TravelMode? navigationMode,
  }) async {
    currentPositionCalls++;
    final failure = error;
    if (failure != null) throw failure;
    return current;
  }

  @override
  Stream<NavigationPosition> watchPositions(TravelMode mode) {
    watchCalls++;
    return _positions.stream;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return settingsOpenResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return settingsOpenResult;
  }
}

class MemoryRouteStore implements LocalRouteStore {
  List<Place> favorites = [];
  List<RecentRoute> recents = [];
  bool historyEnabled = false;
  bool voiceEnabled = true;
  Object? clearRecentsError;
  Object? saveFavoritesError;
  Object? saveHistoryError;
  Object? saveRecentsError;
  Object? saveVoiceError;

  @override
  Future<void> clearRecents() async {
    if (clearRecentsError case final error?) throw error;
    recents = [];
  }

  @override
  Future<List<Place>> loadFavorites() async => List.of(favorites);

  @override
  Future<bool> loadHistoryEnabled() async => historyEnabled;

  @override
  Future<List<RecentRoute>> loadRecents() async => List.of(recents);

  @override
  Future<bool> loadVoiceEnabled() async => voiceEnabled;

  @override
  Future<void> saveFavorites(List<Place> value) async {
    if (saveFavoritesError case final error?) throw error;
    favorites = List.of(value);
  }

  @override
  Future<void> saveHistoryEnabled(bool enabled) async {
    if (saveHistoryError case final error?) throw error;
    historyEnabled = enabled;
  }

  @override
  Future<void> saveRecents(List<RecentRoute> value) async {
    if (saveRecentsError case final error?) throw error;
    recents = List.of(value);
  }

  @override
  Future<void> saveVoiceEnabled(bool enabled) async {
    if (saveVoiceError case final error?) throw error;
    voiceEnabled = enabled;
  }
}

class FakeSpeech implements SpeechGateway {
  final List<String> messages = [];
  ValueChanged<String>? errorHandler;
  bool initialized = false;
  int stopCalls = 0;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    errorHandler = handler;
  }

  @override
  Future<void> speak(String text) async {
    initialized = true;
    messages.add(text);
  }

  @override
  Future<void> stop() async => stopCalls++;
}

class FakeWakeLock implements WakeLockGateway {
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;
  Object? disableError;

  @override
  Future<void> disable() async {
    disableCalls++;
    enabled = false;
    if (disableError case final error?) throw error;
  }

  @override
  Future<void> enable() async {
    enableCalls++;
    enabled = true;
  }
}

class FakeExternalNavigation implements ExternalNavigationGateway {
  @override
  List<NavigationProvider> availableProviders = const [
    NavigationProvider.google,
    NavigationProvider.apple,
  ];
  int launchCalls = 0;
  NavigationProvider? lastProvider;
  bool launchResult = true;

  @override
  Future<bool> launch({
    required NavigationProvider provider,
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) async {
    launchCalls++;
    lastProvider = provider;
    return launchResult;
  }
}

class TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return const _SolidTileImageProvider();
  }
}

class _SolidTileImageProvider extends ImageProvider<_SolidTileImageProvider> {
  const _SolidTileImageProvider();

  @override
  Future<_SolidTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SolidTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_createImage());
  }

  Future<ImageInfo> _createImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFE8ECF5), BlendMode.src);
    final image = await recorder.endRecording().toImage(1, 1);
    return ImageInfo(image: image);
  }
}

class TestAppHarness {
  TestAppHarness({
    FakeGeoplateforme? api,
    FakeDeviceLocation? location,
    MemoryRouteStore? store,
    FakeSpeech? speech,
    FakeWakeLock? wakeLock,
    FakeExternalNavigation? externalNavigation,
  }) : api = api ?? FakeGeoplateforme(),
       location = location ?? FakeDeviceLocation(),
       store = store ?? MemoryRouteStore(),
       speech = speech ?? FakeSpeech(),
       wakeLock = wakeLock ?? FakeWakeLock(),
       externalNavigation = externalNavigation ?? FakeExternalNavigation() {
    dependencies = AppDependencies(
      geoplateforme: this.api,
      location: this.location,
      store: this.store,
      speech: this.speech,
      wakeLock: this.wakeLock,
      externalNavigation: this.externalNavigation,
      tileProvider: TransparentTileProvider(),
    );
  }

  final FakeGeoplateforme api;
  final FakeDeviceLocation location;
  final MemoryRouteStore store;
  final FakeSpeech speech;
  final FakeWakeLock wakeLock;
  final FakeExternalNavigation externalNavigation;
  late final AppDependencies dependencies;

  Future<void> dispose() => location.close();
}
