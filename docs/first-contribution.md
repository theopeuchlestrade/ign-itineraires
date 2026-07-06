# First Contribution

This guide gets you started with a small contribution to IGN Itinéraires.
For the full contribution guidelines, see [`../CONTRIBUTING.md`](../CONTRIBUTING.md).

## 1. Get the Code

```sh
git clone https://github.com/theopeuchlestrade/ign-itineraires.git
cd ign_itineraires
```

## 2. Run the App

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

If Flutter cannot launch Chrome, run:
```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8088
```

Then open <http://127.0.0.1:8088>.

## 3. Make a Small Change

Try a simple change like fixing a typo in the UI or updating a documentation string.

## 4. Verify and Submit

Run the essential checks:
```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool
flutter analyze
flutter test --coverage --exclude-tags "live || golden"
```

**Need more details?** See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for:
- Complete quality checks
- Live service tests
- Golden image management
- Pull request guidelines
- Privacy and network change requirements

Before opening a pull request:
- Explain behavior, privacy, network, or permission changes;
- Include tests for changed behavior;
- Confirm that no private address, route, location, secret, or generated test failure was committed.
