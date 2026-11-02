# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

No version has been tagged yet. The section below describes the complete
initial baseline represented by the repository's root commit.

## [Unreleased]

### Fixed

- Load the current web release through a fresh manifest and fingerprinted
  executables, retiring the legacy Flutter offline cache so returning visitors
  do not need a second reload to receive a routing-service update.

### Added

- Added address and place search using the French Géoplateforme.
- Added car and pedestrian route calculation with distance, duration, geometry,
  and turn-by-turn steps.
- Added foreground GPS guidance with map orientation, French voice
  instructions with locally stored mute preference, off-route recalculation,
  and screen wake-lock handling.
- Added mobile GPS quality states, precise-location checks, stale-fix
  rejection, uncertainty display, conservative arrival confirmation, and
  heading-aware route matching.
- Added departure from a selected address or the current GPS position.
- Added IGN Plan WMTS base map and explicit handoff to Google Maps, Apple Maps,
  or compatible external navigation applications.
- Added on-device favorites and opt-in recent-route history.
- Added responsive light and dark interfaces for web, Android, and iOS.
- Added deterministic unit, widget, golden, integration, and live contract
  tests with an enforced core coverage threshold.
- Added the community, governance, security, support, and brand policies needed
  for public contributions.
- Added issue and pull request templates, dependency automation, secret
  scanning, workflow linting, and local contributor tooling.
- Added departure/destination inversion and keyboard navigation for address
  suggestions.
- Added actionable route retries with rate-limit countdowns, navigation-start
  retry, and an explicit degraded state when map tiles repeatedly fail.
- Added deterministic synthetic GPS trace replay scenarios for jitter,
  parallel-road offsets, backward fixes, and implausible jumps.
- Added deterministic maneuver-oracle replays, live end-to-end guidance routes,
  nightly Android/iOS simulator journeys, and a coordinate-free physical-device
  diagnostics overlay.

### Changed

- Requires iOS 15 or later with the current Flutter stable SDK.
- Uses the available IGN `bdtopo-valhalla` routing resource because
  `bdtopo-osrm` is no longer advertised by the service, preserving the same public host and POST request privacy.

### Implementation

- Updates the pinned SDK to Flutter 3.47.9 / Dart 3.13.7 and enables web
  1.1.2; uses Ubuntu 24.04 LTS for Linux CI and nginx 1.30.6 stable for the
  production container, with documented upstream support policies.

- Uses a Manrope-based Material 3 identity with bundled font assets.
- Integrates iOS plugins through Swift Package Manager and implements speech
  with first-party Web, Android, and iOS adapters.
- Classifies Géoplateforme failures so presentation code can distinguish
  retryable outages, rate limits, invalid responses, and missing routes.
- Removed duplicate pull-request dependency workflows while retaining the
  blocking CI checks and scheduled vulnerability scan.
- Anchors maneuvers to step geometry, normalizes maneuver vocabulary, aligns
  followed-mode heading to the route when trustworthy, preserves reliable
  reverse headings, and confirms arrival using mode-specific accuracy rules.

### Security

- Restricted application-owned HTTP access to Géoplateforme endpoints.
- Kept continuous GPS tracking and saved routes on the device.
- Prevented pending calculations from restarting location, speech, or wake-lock
  services after pause, stop, backgrounding, or disposal.
- Added dependency vulnerability scanning and documented data flows,
  permissions, and network access.
- Rejects malformed or out-of-range locally stored places and route metrics.
- Replaced public-issue instructions for hosting-data requests with GitHub's
  private privacy channels.
