# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added address and place search using the French Géoplateforme.
- Added car and pedestrian route calculation with distance, duration, geometry,
  and turn-by-turn steps.
- Added foreground GPS guidance, voice instructions, off-route recalculation,
  and screen wake-lock handling.
- Added mobile GPS quality states, precise-location checks, stale-fix
  rejection, uncertainty display, conservative arrival confirmation, and
  heading-aware route matching.
- Added IGN Plan map tiles and explicit handoff to compatible external
  navigation applications.
- Added on-device favorites and opt-in recent-route history.
- Added responsive light and dark interfaces for web, Android, and iOS.
- Added deterministic unit, widget, golden, integration, and live contract
  tests with an enforced core coverage threshold.
- Added the community, governance, security, support, and brand policies needed
  for public contributions.
- Added issue and pull request templates, dependency automation, secret
  scanning, workflow linting, and local contributor tooling.

### Fixed

- Fixed dark theme blue colors to align with DSFR specifications, replacing
  custom `#1A1A5C` with official `#3A3AFF` token for cards and primary containers.
  DSFR tokens: `$blue-france-125` (`#3A3AFF`), `$background-action-high-blue-france`.
  Reference: [DSFR color palette](https://www.systeme-de-design.gouv.fr/version-courante/fr/fondamentaux/couleurs-palette).
  Impact: full compliance with French government design system, improved accessibility
  and contrast in dark mode.

### Security

- Restricted application-owned HTTP access to Géoplateforme endpoints.
- Kept continuous GPS tracking and saved routes on the device.
- Prevented pending calculations from restarting location, speech, or wake-lock
  services after pause, stop, backgrounding, or disposal.
- Added dependency vulnerability scanning and documented data flows,
  permissions, and network access.
