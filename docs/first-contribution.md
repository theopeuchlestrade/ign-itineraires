# First Contribution

This guide gets a fresh checkout into a useful local state for a small
documentation, UI, or test contribution.

## 1. Clone and Prepare

```sh
git clone https://github.com/theopeuchlestrade/ign-itineraires.git
cd ign_itineraires
flutter pub get --enforce-lockfile
```

No backend, API key, or `.env` file is required.

## 2. Run the Web App

```sh
flutter run -d chrome
```

If Flutter cannot launch Chrome:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8088
```

Open <http://127.0.0.1:8088>. Browser geolocation works on localhost without a
development HTTPS certificate. Use public landmarks rather than personal
addresses while testing or sharing screenshots.

## 3. Verify a Small Change

Run the checks relevant to the change:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
flutter test --coverage --exclude-tags live
dart run tool/check_coverage.dart
ruby scripts/check_markdown_links.rb
```

Live tests contact public Géoplateforme services and are intentionally
separate:

```sh
flutter test test/live --tags live --concurrency=1
```

For platform builds, integration journeys, golden-test behavior, and the full
matrix, read [`TEST_PLAN.md`](TEST_PLAN.md).

## 4. Open a Pull Request

Before opening a pull request:

- read [`../CONTRIBUTING.md`](../CONTRIBUTING.md);
- explain behavior, privacy, network, or permission changes;
- include tests for changed behavior;
- confirm that no private address, route, location, secret, or generated test
  failure was committed.
