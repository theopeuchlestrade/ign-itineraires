<p align="center">
  <img src=".github/assets/ign_itineraires_logo.svg" alt="IGN Itinéraires logo" width="120">
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

The application is currently available via GitHub Pages at
<https://theopeuchlestrade.github.io/ign-itineraires/>. Until further notice,
this repository remains the only officially published artifact.

> [!IMPORTANT]
> This is an unofficial open source project. It is not
> affiliated with IGN or the French administration. Its use of cartes.gouv.fr
> services and attribution does not imply official status or endorsement.

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

## Architecture Overview

The application uses injectable gateways around Géoplateforme access,
geolocation, local storage, speech, screen wake lock, and external navigation.
Routing domain logic and guidance calculations remain independent from Flutter
widgets and platform plugins.

For details, see [`docs/architecture.md`](docs/architecture.md).

## Privacy

Application-owned HTTP requests are restricted to `data.geopf.fr`. Search text and
route coordinates are sent to Géoplateforme as needed. Continuous GPS fixes,
favorites, and optional recent routes stay on the device.

See [`PRIVACY.md`](PRIVACY.md) for complete data flows, permissions, storage, and hosts.

## Licence

The source code is distributed under the
**[European Union Public Licence 1.2](LICENSE)**.

The source-code licence does not grant a general right to reuse IGN Itinéraires names,
logos, icons, domains, or product identity. See
[`TRADEMARKS.md`](TRADEMARKS.md).

## Documentation

- [Contributing](CONTRIBUTING.md) — How to contribute to the project
- [First Contribution](docs/first-contribution.md) — Quick start for new contributors
- [Architecture](docs/architecture.md) — Technical architecture details
- [Test Plan](docs/TEST_PLAN.md) — Platform matrix and manual scenarios
- [Release Checklist](docs/RELEASE_CHECKLIST.md) — Release preparation steps
- [Privacy Policy](PRIVACY.md) — Data flows and permissions
- [Security Policy](SECURITY.md) — Vulnerability reporting
- [Code of Conduct](CODE_OF_CONDUCT.md) — Community guidelines
- [Governance](GOVERNANCE.md) — Decision-making model
- [Roadmap](ROADMAP.md) — Planned features and priorities
- [Support](SUPPORT.md) — Support guidelines
- [Third-Party Notices](THIRD_PARTY_NOTICES.md) — Dependencies and attribution
