# Architecture

IGN Itinéraires is a standalone Flutter application for route planning and
foreground GPS guidance. The same codebase targets web, Android, and iOS.

## Runtime Shape

- Flutter renders the route planner, map, saved routes, and guidance screens.
- The application calls public Géoplateforme services directly for address
  autocomplete and car or pedestrian route calculation.
- `flutter_map` renders IGN Plan tiles and route geometry.
- Geolocator supplies foreground positions after platform permission is
  granted.
- Favorites, recent routes, and the speech preference are stored locally with
  shared preferences.
- Speech, wake-lock, geolocation, external navigation, and remote API behavior
  are exposed through gateways so deterministic tests can replace them. Speech
  uses Web SpeechSynthesis in browsers, Android `TextToSpeech`, and iOS
  `AVSpeechSynthesizer`, without a third-party speech plugin. iOS plugins are
  integrated exclusively through Swift Package Manager.
- There is no IGN Itinéraires backend, account, analytics SDK, advertising tracker,
  or cloud synchronization.

## Source Layout

The routing feature follows a small layered structure under
`lib/src/features/routing/`:

- `domain/` contains route and guidance models plus the navigation engine;
- `data/` implements public API access, geolocation, local storage, speech,
  wake lock, and external navigation;
- `presentation/` contains planning and navigation controllers, lifecycle
  coordination, pages, and responsive widgets;
- `app_dependencies.dart` creates production dependencies and supports test
  injection;
- `network_endpoints.dart` defines the application endpoint registry.

Domain logic does not depend on Flutter widgets or platform plugins.
Controllers coordinate gateways and expose state to the presentation layer.
Their mutable session fields remain private; widgets consume read-only getters
and invoke explicit commands. Géoplateforme failures carry a stable category
and optional retry delay so retry policy does not depend on parsing translated
messages.
`navigation_lifecycle.dart` keeps app foreground/background transitions outside
the page widget while the navigation engine remains platform-independent.

## Data Flow

1. Local preferences are loaded without requesting location permission.
2. After an explicit tap on “Use my position”, foreground location permission
   is requested and the resulting position stays in memory.
3. Address text is sent to Géoplateforme autocomplete.
4. Selected coordinates are sent to route calculation through `POST`.
5. The returned geometry and instructions are held in memory and rendered.
6. During guidance, foreground GPS fixes are processed locally.
7. A new position is sent only when guidance starts or a route is recalculated.
8. Favorites and opt-in history remain on the device.

See [`../PRIVACY.md`](../PRIVACY.md) for the complete data, permission, and
retention policy.

## Network Boundary

Application-owned HTTP requests are built only for `data.geopf.fr`. The
GitHub Pages deployment additionally carries a static Content Security Policy
meta tag that limits image and connection targets to this boundary. The
container deployment sends the same network boundary through HTTP security
headers. Google Maps and Apple Maps URLs are created only after an explicit
user action. System speech engines may process text locally or remotely. Any
new host or data flow requires an endpoint-registry change, tests, and a
privacy review.

## Public vs Private Operations

This repository contains source code, public CI, local build instructions,
unsigned build validation, and the reproducible non-root web container with its
public HTTP security policy. Official deployment credentials, VPS
configuration, monitoring, release promotion, mobile signing, app-store
publication, and rollback operations remain outside the public repository.
