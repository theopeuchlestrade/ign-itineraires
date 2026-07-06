# Contributing to ign_itineraires

Thanks for contributing to IGN Itinéraires.

## Prerequisites

- Flutter 3.44.1 or a compatible stable release
- Dart SDK supplied by Flutter
- Chrome for web development
- Android Studio or Xcode only when working on the corresponding native target

No IGN Itinéraires backend, API key, or local environment file is required. The
application calls public Géoplateforme services directly.

For a guided first setup, use
[`docs/first-contribution.md`](docs/first-contribution.md).

## Run the App

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Web geolocation works on `localhost` and `127.0.0.1`. Use an HTTPS origin for
other web deployments.

## Local Hooks

Install the repository pre-commit hook:

```sh
sh scripts/install-hooks.sh
```

The hook checks Dart formatting and runs static analysis. It does not replace
the complete test suite.

## Quality Checks

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
flutter test --coverage --exclude-tags "live || golden"
dart run tool/check_coverage.dart
ruby scripts/check_markdown_links.rb
```

Run the live contract tests separately because they contact public services:

```sh
flutter test test/live --tags live --concurrency=1
```

Golden images are canonical on Linux. Update them through the pinned container
instead of accepting platform-specific macOS rendering:

```sh
sh scripts/check_goldens.sh
```

Update intentional changes with:

```sh
sh scripts/update_goldens.sh
```

Platform builds and deterministic integration journeys are documented in
[`docs/TEST_PLAN.md`](docs/TEST_PLAN.md).

## Privacy and Network Changes

Changes that add a host, transmit new data, collect analytics, add background
location, or alter local storage must update:

- `PRIVACY.md`;
- `lib/src/network_endpoints.dart` and its tests when the endpoint registry
  changes;
- the relevant platform permission declarations;
- tests covering consent, failure, and data-retention behavior.

Do not include personal addresses, routes, precise locations, or device logs
containing private data in issues, fixtures, screenshots, or golden files.

## Project Policies

- Follow `CODE_OF_CONDUCT.md` in project spaces.
- Read `SUPPORT.md` before opening support-style issues.
- Read `GOVERNANCE.md` for the maintainer-led decision model.
- Read `ROADMAP.md` before proposing large feature work.
- Follow `TRADEMARKS.md` for changes to names, icons, screenshots, copy, or
  third-party marks.

## Pull Requests

- Describe the context, behavior change, privacy impact, and verification.
- Keep patches focused and add tests for changed behavior.
- Use a title or squash commit that can become a clear release note. Conventional
  Commit titles are preferred, for example:
  - `feat(routing): add bicycle route mode`
  - `fix(navigation): retain route after a failed recalculation`
  - `security(network): restrict external navigation hosts`
  - `chore(deps): update Flutter dependencies`
- `CHANGELOG.md` is generated from commits during release preparation; edit it
  manually only for the initial baseline or historical corrections.
- Report vulnerabilities privately according to `SECURITY.md`.
