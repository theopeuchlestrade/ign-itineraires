# Test Plan

This document defines the ongoing validation of IGN Itinéraires. Test fixtures use
fixed public places in Paris and La Réunion. Personal positions and real traces
must never be committed, uploaded as artifacts, or copied into defect reports.

## Current Baseline

The local validation completed on 13 July 2026 produced:

- 129 passing unit and widget tests, plus nine passing exact golden and keyboard cases;
- 92.5% coverage for routing domain logic, controllers, and API parsing;
- a successful self-contained web release build.

The most recent complete platform validation, completed on 11 July 2026, also
produced:

- Four passing deterministic Chrome journeys
- Four passing live Geoplatform contracts
- Successful web release, Android debug, and iOS Simulator builds

This baseline is informative. The current CI result always takes precedence.

## Validation Levels

### Pull Request

The CI must pass before merging:

- Dart format and static analysis;
- Unit, widget, and golden tests, excluding `live` tests;
- Minimum 90% coverage on domain, IGN parsing, and controllers;
- Deterministic planning, persistence, failure, and guidance-start flows in Chrome;
- Web release build, production container smoke test, Android debug APK, and
  unsigned iOS Simulator build;
- OSV dependency scans for the Dart and npm lockfiles.

Equivalent local commands:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
flutter test --coverage --exclude-tags "live || golden"
dart run tool/check_coverage.dart
sh scripts/build_web_release.sh /ign-itineraires/
ruby scripts/check_web_release.rb build/web /ign-itineraires/
flutter build web --wasm --release --no-web-resources-cdn \
  --base-href /ign-itineraires/ --output build/web-wasm
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

Golden references are produced only with the pinned Linux environment:

```sh
sh scripts/check_goldens.sh
```

Update intentionally changed references with:

```sh
sh scripts/update_goldens.sh
```

Web integration flows require ChromeDriver:

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

Chrome validates planning, persistence, failure states, and guidance startup.
The Flutter Web integration runner can stall when it injects gestures into an
active `FlutterMap`; continuous navigation interactions therefore run on
Android and iOS and are also covered with deterministic controller tests.

### Nightly Validation

The scheduled workflow executes:

- Real autocomplete, route, and WMTS contracts on `data.geopf.fr`;
- A car trip in Paris and a pedestrian trip in La Réunion;
- Integration flow on Android Emulator API 24;
- Scan for known vulnerabilities in `pubspec.lock`.

To manually trigger contracts:

```sh
flutter test test/live --tags live --concurrency=1
```

A public-service outage does not block a pull request because live tests are
excluded there. It does block a release until all contracts have succeeded
within the previous 24 hours.

## Test Matrix

| Surface | Minimum Configuration | Checks |
| --- | --- | --- |
| Web macOS | Stable Chrome | responsive, GPS, TTS, two-finger movement, pinch |
| Web macOS | Stable Safari | HTTPS GPS, voice, map, local storage |
| Web macOS | Stable Firefox | map, search, calculation, errors |
| Android | Recent real device | permissions, continuous GPS, TTS, standby, external app |
| Android | Emulator API 24 | installation, startup, and simulated flow |
| iOS | Recent real iPhone | permissions, continuous GPS, TTS, standby, Apple Maps |
| Old iOS | TestFlight on iOS 13–15 | installation and critical flow, if a device is available |
| Tablet | iPad or Android tablet | portrait/landscape layout and enlarged text |

If no iOS 13–15 device is available, record the target as compiled but not
physically certified in the release checklist.

## Functional Scenarios

### Planning

1. Use current position, then replace departure with an address.
2. Search for an address with accents and a name present in multiple cities.
3. Calculate car and pedestrian routes in mainland France and overseas territories.
4. Verify route, zoom, distance, duration, IGN version, and route sheet.
5. Add/remove a favorite.
6. Confirm that history is disabled by default.
7. Enable history, recalculate, restart, then clear history.
8. Verify that a destination outside the covered area produces an understandable message.

### Built-in Guidance

1. Start from a fresh GPS position.
2. Verify precise-location detection, the 25m pedestrian threshold, and the
   35m car threshold.
3. Move the map, verify tracking stops, then recenters.
4. Inject three positions off the route and observe a single recalculation.
5. Disconnect network: the old route must remain visible.
6. Restore network after 20 seconds and verify a new attempt.
7. Background then reopen the application: GPS, voice, and screen wake lock are suspended, then resumed with a recalculation.
8. Arrive at destination: voice, GPS, and screen wake lock are released.
9. Stop manually and verify that no tracking continues.
10. Pause or stop while initial calculation and recalculation requests are
    still pending; completing them must not restart GPS, voice, or wake lock.
11. Test stale fixes, approximate permission, stationary heading, GPS jumps,
    parallel roads, crossings, a U-turn, signal loss, and recovery after two
    reliable fixes.

### Permissions and Failures

- Location disabled, denied, and permanently denied;
- Precision greater than 50m and interrupted GPS flow;
- No network, timeout, `429`, `5xx` responses, and invalid JSON;
- TTS unavailable: visual guidance continues;
- Screen wake lock unavailable: non-blocking message;
- Google Maps or Apple Maps unavailable, or external opening refused.

## Accessibility, Privacy, and Performance

- Test light/dark, mobile/tablet/desktop, and text at 200%.
- Navigate the screen with keyboard, then VoiceOver, then TalkBack.
- Verify contrast, button labels, and absence of overflow.
- Check in network tools that only domains documented in `PRIVACY.md` are contacted.
- Confirm the absence of background location permission.
- Perform 30 minutes of guidance in profile mode: no continuous frame errors, no thermal warnings, and stable memory between the 10th and 30th minute.
- A real car trip must be tested by a passenger, never by the driver.
- Certify built-in guidance only on real Android and iOS devices. Browser
  guidance remains experimental.
- Complete an urban and open-area pedestrian route plus urban and fast-road
  car routes on one recent Android phone and one recent iPhone. Accept no
  false reroute, wrong instruction, premature arrival, or tracking after
  backgrounding.

## Defect Management

- **Critical**: crash, dangerous guidance, position leak, or excessive permission — publication prohibited.
- **Major**: unusable calculation/guidance on a platform — publication prohibited.
- **Minor**: visual defect or imperfect message with workaround — accepted only if documented.

Public reports must not contain personal addresses. Request the application version, OS, browser, and an equivalent public trip.
