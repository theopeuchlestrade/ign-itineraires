import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_launcher.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/features/routing/presentation/widgets/ign_route_map.dart';
import 'package:ign_itineraires/src/network_endpoints.dart';

import 'support/test_fixtures.dart';

void main() {
  test('application HTTP traffic is restricted to the Géoplateforme', () {
    expect(NetworkEndpoints.applicationHttpHosts, {'data.geopf.fr'});
    expect(Uri.parse(ignPlanWmtsUrl).host, 'data.geopf.fr');
  });

  test('external navigation hosts stay in the endpoint registry', () {
    const launcher = NavigationLauncher();
    final hosts = {
      launcher
          .buildUri(
            provider: NavigationProvider.google,
            start: parisStart,
            destination: parisDestination,
            mode: TravelMode.car,
          )
          .host,
      launcher
          .buildUri(
            provider: NavigationProvider.apple,
            start: parisStart,
            destination: parisDestination,
            mode: TravelMode.pedestrian,
          )
          .host,
    };

    expect(hosts, NetworkEndpoints.explicitExternalNavigationHosts);
    expect(NetworkEndpoints.explicitPolicyHosts, {'theopeuchlestrade.github.io'});
    expect(NetworkEndpoints.registeredHosts, {
      'data.geopf.fr',
      'www.google.com',
      'maps.apple.com',
      'theopeuchlestrade.github.io',
    });
  });
}
