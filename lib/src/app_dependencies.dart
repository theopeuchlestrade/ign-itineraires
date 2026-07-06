import 'package:flutter_map/flutter_map.dart';
import 'package:ign_itineraires/src/features/routing/data/device_location_service.dart';
import 'package:ign_itineraires/src/features/routing/data/geoplateforme_api.dart';
import 'package:ign_itineraires/src/features/routing/data/local_route_store.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_launcher.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_services.dart';

class AppDependencies {
  AppDependencies({
    required this.geoplateforme,
    required this.location,
    required this.store,
    required this.speech,
    required this.wakeLock,
    required this.externalNavigation,
    this.tileProvider,
  });

  factory AppDependencies.production() => AppDependencies(
    geoplateforme: GeoplateformeApi(),
    location: DeviceLocationService(),
    store: SharedPreferencesRouteStore(),
    speech: FlutterSpeechService(),
    wakeLock: const ScreenWakeLockService(),
    externalNavigation: const NavigationLauncher(),
  );

  final GeoplateformeGateway geoplateforme;
  final DeviceLocationGateway location;
  final LocalRouteStore store;
  final SpeechGateway speech;
  final WakeLockGateway wakeLock;
  final ExternalNavigationGateway externalNavigation;
  final TileProvider? tileProvider;

  void close() {
    final api = geoplateforme;
    if (api is GeoplateformeApi) api.close();
  }
}
