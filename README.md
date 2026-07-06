<p align="center">
  <img src=".github/assets/ign_itineraires_logo.svg" alt="IGN Itinéraires logo" width="180">
</p>

# IGN Itinéraires

[![CI](https://github.com/theopeuchlestrade/ign-itineraires/actions/workflows/ci.yml/badge.svg)](https://github.com/theopeuchlestrade/ign-itineraires/actions/workflows/ci.yml)
[![Dependency vulnerability scan](https://github.com/theopeuchlestrade/ign-itineraires/actions/workflows/osv-scanner.yml/badge.svg)](https://github.com/theopeuchlestrade/ign-itineraires/actions/workflows/osv-scanner.yml)
[![Flutter 3.44.1](https://img.shields.io/badge/Flutter-3.44.1-02569B.svg?logo=flutter)](https://flutter.dev)
[![EUPL-1.2 License](https://img.shields.io/badge/license-EUPL--1.2-brightgreen.svg)](LICENSE)

**IGN Itinéraires** is a privacy-conscious Flutter application for car and
pedestrian route planning and foreground GPS guidance. It targets web, Android,
and iOS and calls public French Géoplateforme services directly.

The repository and Dart package are named `ign_itineraires`.

Planned official web address: <https://map.fiestaaa.app>. Until the deployment
legal notice and privacy metadata are complete, this repository is the only
officially published artifact.

> [!IMPORTANT]
> This is an unofficial open source project. It is not
> affiliated with IGN or the French administration. Its use of cartes.gouv.fr
> services and attribution does not imply official status or endorsement.

## Contents

- [Features](#features)
- [Getting Started](#getting-started)
- [Architecture and Data](#architecture-and-data)
- [Development](#development)
- [Builds and Releases](#builds-and-releases)
- [Security](#security)
- [Licence](#licence)
- [Contributing](#contributing)
- [Project Documentation](#project-documentation)

## Features

- Address and place search through `data.geopf.fr` autocomplete
- Car and pedestrian routes with geometry, distance, duration, and steps
- IGN Plan WMTS base map
- Departure from a selected address or the current GPS position
- Foreground GPS guidance on Android and iOS with signal-quality checks, map
  orientation, and off-route recalculation
- French voice instructions with a locally stored mute preference
- Explicit handoff to Google Maps, Apple Maps, or compatible Android apps
- On-device favorites and opt-in recent-route history
- Responsive light and dark interfaces

The application is anonymous and has no IGN Itinéraires backend, account system,
analytics SDK, advertising tracker, or cloud synchronization.

Built-in guidance tracks location only while the application is in the
foreground. Background guidance, lock-screen guidance, real-time traffic,
CarPlay, Android Auto, and offline maps are outside the current scope.
Browser guidance remains experimental because web geolocation quality depends
strongly on the device and browser; use an external navigation application for
reliable web-originated trips.

Mobile guidance pauses instructions when the operating system reports reduced
location precision, when fixes are stale, or when horizontal accuracy is worse
than 25 m on foot or 35 m by car. It resumes only after two reliable fixes.

## Getting Started

### Prerequisites

- Flutter 3.44.1 or a compatible stable release
- Chrome for web development
- Android API 24 or later for Android builds
- iOS 13 or later for iOS builds

No API key, backend, or `.env` file is required.

### Quick Start

```sh
git clone https://github.com/theopeuchlestrade/ign-itineraires.git
cd ign_itineraires
flutter pub get --enforce-lockfile
flutter run -d chrome
```

If Flutter cannot launch Chrome:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8088
```

Then open <http://127.0.0.1:8088>.

Web geolocation works on `localhost` and `127.0.0.1` without a local HTTPS
certificate. Production web deployments require HTTPS for geolocation.

## Architecture and Data

The application uses injectable gateways around Géoplateforme access,
geolocation, local storage, speech, screen wake lock, and external navigation.
Routing domain logic and guidance calculations remain independent from Flutter
widgets and platform plugins.

Application-owned HTTP requests are restricted to `data.geopf.fr`. Search text and
route coordinates are sent to Géoplateforme as needed. Continuous GPS fixes,
favorites, and optional recent routes stay on the device; a position is sent
again only when guidance starts or a route is recalculated.

The Manrope font is bundled and is not downloaded at runtime. Its SIL Open Font
License is included in
[`assets/fonts/OFL.txt`](assets/fonts/OFL.txt). The production container also
self-hosts Flutter's Roboto fallback and its Apache 2.0 license from the pinned
Flutter SDK.

See:

- [`PRIVACY.md`](PRIVACY.md) for data flows, permissions, storage, and hosts;
- [`docs/architecture.md`](docs/architecture.md) for layers and runtime flow;
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for dependencies,
  services, attribution, and marks.

## Development

Install the optional repository hook:

```sh
sh scripts/install-hooks.sh
```

Run the main quality suite:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
flutter test --coverage --exclude-tags "live || golden"
dart run tool/check_coverage.dart
ruby scripts/check_markdown_links.rb
```

Core route, controller, and API parsing coverage must remain at or above 80%.
Golden references are generated on the canonical Linux toolchain:

```sh
sh scripts/check_goldens.sh
```

Update an intentionally changed reference with:

```sh
sh scripts/update_goldens.sh
```

Live service contracts are separate from pull-request tests:

```sh
flutter test test/live --tags live --concurrency=1
```

Deterministic web journeys require ChromeDriver:

```sh
chromedriver --port=4444
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_flow_test.dart \
  -d web-server \
  --web-port=7357 \
  --browser-name=chrome \
  --timeout=120 \
  --screenshot=build/test-screenshots
```

The complete platform matrix and manual scenarios are in
[`docs/TEST_PLAN.md`](docs/TEST_PLAN.md).

The current `flutter_tts` release still uses CocoaPods on iOS and does not
support Flutter's Swift Package Manager integration. CI keeps the CocoaPods
build covered until upstream support is available. Flutter also reports
forward-compatibility warnings for `flutter_tts` WebAssembly interop and for
the Kotlin Gradle integration used by `flutter_tts` and `wakelock_plus`; these
dependencies must be upgraded when compatible releases become available.

## Builds and Releases

```sh
flutter build web --release
flutter build apk --debug
flutter build ios --simulator --no-codesign
docker build -t ign-itineraires:local .
```

Official hosting, mobile signing, store publication, and production operations
are maintained outside this public repository. Release preparation follows
[`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md), and notable changes
are recorded in [`CHANGELOG.md`](CHANGELOG.md).

The official web image is built from the public `Dockerfile`. Android and iOS
release signing and store publication are not part of the initial web release;
the public CI validates debug/simulator builds only.

## Security

Do not report vulnerabilities through public issues. Follow
[`SECURITY.md`](SECURITY.md) and use GitHub Private Vulnerability Reporting
when available.

CI runs workflow linting, secret scanning, dependency review, OSV dependency
scanning, analysis, tests, coverage enforcement, integration checks, and
platform builds.

## Licence

The source code is distributed under the
**[European Union Public Licence 1.2](LICENSE)**.

The source-code licence does not grant a general right to reuse IGN Itinéraires names,
logos, icons, domains, or product identity. See
[`TRADEMARKS.md`](TRADEMARKS.md).

## Contributing

Contributions are welcome. Start with:

- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`docs/first-contribution.md`](docs/first-contribution.md)
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- [`GOVERNANCE.md`](GOVERNANCE.md)
- [`ROADMAP.md`](ROADMAP.md)
- [`SUPPORT.md`](SUPPORT.md)

Any new network dependency, permission, data collection, background behavior,
or local storage must be reflected in `PRIVACY.md` and covered by tests.

## Project Documentation

- [Architecture](docs/architecture.md)
- [First contribution](docs/first-contribution.md)
- [Privacy](PRIVACY.md)
- [Test plan](docs/TEST_PLAN.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Security policy](SECURITY.md)
- [Roadmap](ROADMAP.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Brand and asset policy](TRADEMARKS.md)
