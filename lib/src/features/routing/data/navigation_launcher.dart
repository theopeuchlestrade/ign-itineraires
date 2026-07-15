import 'package:flutter/foundation.dart';
import 'package:ign_itineraires/src/features/routing/domain/routing_models.dart';
import 'package:ign_itineraires/src/network_endpoints.dart';
import 'package:url_launcher/url_launcher.dart';

enum NavigationProvider {
  google,
  apple,
  system;

  String get label => switch (this) {
    NavigationProvider.google => 'Google Maps',
    NavigationProvider.apple => 'Apple Plans',
    NavigationProvider.system => 'Application par défaut',
  };
}

abstract interface class ExternalNavigationGateway {
  List<NavigationProvider> get availableProviders;

  Future<bool> launch({
    required NavigationProvider provider,
    required Place start,
    required Place destination,
    required TravelMode mode,
  });
}

class NavigationLauncher implements ExternalNavigationGateway {
  const NavigationLauncher();

  @override
  List<NavigationProvider> get availableProviders {
    if (kIsWeb) {
      return const [NavigationProvider.google, NavigationProvider.apple];
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => const [
        NavigationProvider.apple,
        NavigationProvider.google,
      ],
      TargetPlatform.android => const [
        NavigationProvider.system,
        NavigationProvider.google,
      ],
      _ => const [NavigationProvider.google],
    };
  }

  Uri buildUri({
    required NavigationProvider provider,
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) {
    final origin = '${start.latitude},${start.longitude}';
    final end = '${destination.latitude},${destination.longitude}';
    return switch (provider) {
      NavigationProvider.google => Uri.https(
        NetworkEndpoints.googleMapsHost,
        '/maps/dir/',
        {
          'api': '1',
          'origin': origin,
          'destination': end,
          'travelmode': mode.googleValue,
        },
      ),
      NavigationProvider.apple => Uri.https(
        NetworkEndpoints.appleMapsHost,
        '/',
        {'saddr': origin, 'daddr': end, 'dirflg': mode.appleValue},
      ),
      NavigationProvider.system => Uri(
        scheme: 'geo',
        path: '0,0',
        query: 'q=${Uri.encodeComponent(end)}',
      ),
    };
  }

  @override
  Future<bool> launch({
    required NavigationProvider provider,
    required Place start,
    required Place destination,
    required TravelMode mode,
  }) {
    return launchUrl(
      buildUri(
        provider: provider,
        start: start,
        destination: destination,
        mode: mode,
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}
