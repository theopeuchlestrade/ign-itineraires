import 'dart:io';

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
    expect(NetworkEndpoints.explicitPolicyHosts, {
      'theopeuchlestrade.github.io',
    });
    expect(NetworkEndpoints.registeredHosts, {
      'data.geopf.fr',
      'www.google.com',
      'maps.apple.com',
      'theopeuchlestrade.github.io',
    });
  });

  test('native legal notice uses the GitHub Pages project path', () {
    expect(
      NetworkEndpoints.officialLegalNoticeUri.toString(),
      'https://theopeuchlestrade.github.io/ign-itineraires/legal.html',
    );
    final legal = File('web/legal.html').readAsStringSync();
    expect(legal, contains('<a href="./">Retour à IGN Itinéraires</a>'));
  });

  test('web shell declares French language and responsive metadata', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('<html lang="fr">'));
    expect(index, contains('name="viewport"'));
    expect(index, contains('name="theme-color" content="#255F85"'));
  });

  test('GitHub Pages CSP meta keeps web traffic on registered hosts', () {
    final html = File('web/index.html').readAsStringSync();
    final match = RegExp(
      r'http-equiv="Content-Security-Policy"\s+content="([^"]+)"',
      dotAll: true,
    ).firstMatch(html);

    expect(match, isNotNull);
    final csp = match!.group(1)!;
    expect(
      csp,
      contains(
        "connect-src 'self' https://${NetworkEndpoints.geoplateformeHost};",
      ),
    );
    expect(
      csp,
      contains(
        "img-src 'self' data: blob: "
        'https://${NetworkEndpoints.geoplateformeHost};',
      ),
    );

    final httpsHosts = RegExp(
      r'https://([^\s;]+)',
    ).allMatches(csp).map((match) => match.group(1)!).toSet();

    expect(
      httpsHosts.difference(NetworkEndpoints.applicationHttpHosts),
      isEmpty,
    );
  });
}
