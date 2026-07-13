## Context

Describe the problem or goal addressed by this pull request.

## Changes

-

## Verification

- [ ] `dart format --output=none --set-exit-if-changed lib test integration_test test_driver tool`
- [ ] `flutter analyze`
- [ ] `flutter test --coverage --exclude-tags "live || golden"`
- [ ] `dart run tool/check_coverage.dart`
- [ ] `ruby scripts/check_markdown_links.rb`
- [ ] Relevant web, Android, iOS, integration, golden, or live checks were run.

## Privacy and Security

- [ ] No secret, certificate, signing material, private address, route, precise personal location, or generated test failure is added.
- [ ] Changes to data flows, network hosts, permissions, background behavior, or local storage are documented in `PRIVACY.md`.
- [ ] Brand, screenshot, app icon, logo, map attribution, and third-party mark changes follow `TRADEMARKS.md`.

## Release Notes

- [ ] The pull request title or squash commit is suitable for generated release notes.
- [ ] A Conventional Commit title is preferred, such as `fix(navigation): retain route after recalculation failure`.
- [ ] Documentation and configuration are updated when needed.
