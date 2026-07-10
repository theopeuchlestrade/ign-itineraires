# Release Checklist

> **Note:** Official releases are currently suspended. The application is available
> via GitHub Pages at <https://theopeuchlestrade.github.io/ign-itineraires/>
> until further notice.

Duplicate this document for each version and keep the results with release notes.

## Identification

- Version:
- Commit:
- Date:
- Tester:
- Successful Geoplatform contracts at:

## Automation

- [ ] Format and static analysis
- [ ] Unit/widget/golden tests
- [ ] Core coverage ≥ 80%
- [ ] Simulated Chrome flow
- [ ] Web release build
- [ ] Production container build and desktop/mobile smoke checks
- [ ] `ruby scripts/check_release_metadata.rb --source`
- [ ] `ruby scripts/check_release_metadata.rb --deployment`
- [ ] Android build
- [ ] iOS Simulator build
- [ ] Android API 24 nightly
- [ ] Paris and La Réunion contracts within the last 24 hours
- [ ] OSV scan without blocking vulnerabilities

## Documentation

- [ ] `README.md`, `PRIVACY.md`, test plan, and release checklist are current
- [ ] Documentation is written in English and uses canonical, working links
- [ ] Network domains, permissions, storage, and unsupported features match the code
- [ ] IGN attribution and unofficial-project disclaimer are visible

## Web

| Browser | Version | Result | Notes |
| --- | --- | --- | --- |
| Chrome macOS | | ☐ | |
| Safari macOS | | ☐ | |
| Firefox macOS | | ☐ | |

- [ ] Smooth two-finger trackpad movement
- [ ] Functional pinch zoom
- [ ] GPS on localhost and HTTPS
- [ ] TTS and fallback message
- [ ] Responsive mobile, tablet, and desktop
- [ ] GitHub Pages CSP meta allows only required image and connection hosts
- [ ] Container headers allow only required hosts and geolocation for `self`
- [ ] `flutter_tts` still builds on iOS, or its Swift Package Manager warning has an accepted release note
- [ ] Legal notice contains no release marker

## Real Android

- Device:
- Android Version:

- [ ] Permissions accepted, denied, and permanently denied
- [ ] Real pedestrian trip
- [ ] Car trip tested by a passenger
- [ ] Recalculation after simulated off-route
- [ ] French voice and mute button
- [ ] Screen kept active then released
- [ ] Pause/resume after backgrounding
- [ ] Open external GPS application

## Real iPhone

- Device:
- iOS Version:

- [ ] Permissions accepted, denied, and permanently denied
- [ ] Real pedestrian trip
- [ ] Car trip tested by a passenger
- [ ] Recalculation after simulated off-route
- [ ] French voice and mute button
- [ ] Screen kept active then released
- [ ] Pause/resume after backgrounding
- [ ] Open Apple Maps/Google Maps

## Compatibility and Accessibility

- [ ] TestFlight on iOS 13–15
- [ ] If not tested, old compatibility explicitly not certified
- [ ] Portrait and landscape on tablet
- [ ] Text at 200%
- [ ] VoiceOver
- [ ] TalkBack
- [ ] Keyboard navigation
- [ ] Light and dark themes

## Privacy and Endurance

- [ ] Network domains comply with `PRIVACY.md`
- [ ] No background location permission
- [ ] History disabled by default and erasable
- [ ] 30-minute guidance session without memory leak or overheating
- [ ] No addresses or personal traces in logs and screenshots

## Decision

- [ ] No open critical defects
- [ ] No open major defects
- Accepted minor defects:
- Decision: **PUBLISH / BLOCK**
- Approver:
