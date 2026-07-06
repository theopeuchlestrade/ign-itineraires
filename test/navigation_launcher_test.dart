import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_launcher.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';

void main() {
  const launcher = NavigationLauncher();
  const start = Place(label: 'Départ', latitude: 48.86, longitude: 2.33);
  const destination = Place(label: 'Arrivée', latitude: 48.85, longitude: 2.34);

  test('builds Google walking directions with origin and destination', () {
    final uri = launcher.buildUri(
      provider: NavigationProvider.google,
      start: start,
      destination: destination,
      mode: TravelMode.pedestrian,
    );

    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['origin'], '48.86,2.33');
    expect(uri.queryParameters['destination'], '48.85,2.34');
    expect(uri.queryParameters['travelmode'], 'walking');
  });

  test('builds Apple driving directions', () {
    final uri = launcher.buildUri(
      provider: NavigationProvider.apple,
      start: start,
      destination: destination,
      mode: TravelMode.car,
    );

    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters['dirflg'], 'd');
  });
}
