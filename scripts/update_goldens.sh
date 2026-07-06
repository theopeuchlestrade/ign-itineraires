#!/bin/sh
set -eu

readonly image="ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8"
readonly revision="924134a44c189315be2148659913dda1671cbe99"
case "${1:-}" in
  "")
    golden_arguments="--update-goldens"
    ;;
  --check)
    golden_arguments=""
    ;;
  *)
    echo "usage: $0 [--check]" >&2
    exit 2
    ;;
esac
backup_dir="$(mktemp -d)"
had_dart_tool=false
had_plugins_file=false

if [ -d .dart_tool ]; then
  cp -R .dart_tool "${backup_dir}/dart_tool"
  had_dart_tool=true
fi
if [ -f .flutter-plugins-dependencies ]; then
  cp .flutter-plugins-dependencies "${backup_dir}/flutter-plugins-dependencies"
  had_plugins_file=true
fi

restore_local_tool_state() {
  rm -rf .dart_tool
  rm -f .flutter-plugins-dependencies
  if [ "${had_dart_tool}" = true ]; then
    cp -R "${backup_dir}/dart_tool" .dart_tool
  fi
  if [ "${had_plugins_file}" = true ]; then
    cp "${backup_dir}/flutter-plugins-dependencies" .flutter-plugins-dependencies
  fi
  rm -rf "${backup_dir}"
}
trap restore_local_tool_state EXIT

docker run --rm \
  --platform linux/amd64 \
  --user root \
  --volume "$(pwd):/app" \
  --workdir /app \
  "${image}" \
  bash -lc "
    set -euo pipefail
    flutter_root=\"\$(dirname \"\$(dirname \"\$(command -v flutter)\")\")\"
    git -C \"\${flutter_root}\" fetch --depth=1 origin \"${revision}\"
    git -C \"\${flutter_root}\" checkout --detach FETCH_HEAD
    git config --global --add safe.directory /app
    flutter pub get --enforce-lockfile
    flutter test test/app_responsive_test.dart ${golden_arguments}
  "
