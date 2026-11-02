#!/bin/sh
set -eu

base_href="${1:-/}"
flutter build web --release --no-web-resources-cdn --pwa-strategy none --base-href "${base_href}"

dart run tool/prepare_web_release.dart
