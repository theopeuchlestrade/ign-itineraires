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
  are exposed through gateways so deterministic tests can replace them.
- There is no IGN Itinéraires backend, account, analytics SDK, advertising tracker,
  or cloud synchronization.

## Source Layout

The routing feature follows a small layered structure:

- `domain/` contains route and guidance models plus the navigation engine;
- `data/` implements public API access, geolocation, local storage, speech,
  wake lock, and external navigation;
- `presentation/` contains controllers, pages, and widgets;
- `app_dependencies.dart` creates production dependencies and supports test
  injection;
- `network_endpoints.dart` defines the application endpoint registry.

Domain logic does not depend on Flutter widgets or platform plugins.
Controllers coordinate gateways and expose state to the presentation layer.

## Data Flow

1. Address text is sent to Géoplateforme autocomplete.
2. Selected coordinates are sent to route calculation through `POST`.
3. The returned geometry and instructions are held in memory and rendered.
4. During guidance, foreground GPS fixes are processed locally.
5. A new position is sent only when guidance starts or a route is recalculated.
6. Favorites and opt-in history remain on the device.

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
