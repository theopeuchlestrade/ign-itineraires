#!/bin/sh
set -eu

if [ "$(git rev-parse --is-bare-repository)" != "true" ]; then
  echo "Run this script only from a fresh mirror clone." >&2
  exit 2
fi

if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "git-filter-repo is required." >&2
  exit 2
fi

git filter-repo --force --invert-paths \
  --path-glob 'assets/fonts/Marianne-*.otf' \
  --path-regex '(^|.*/)\.![^/]*!.*$'

if git rev-list --objects --all | grep -E 'assets/fonts/Marianne-|/\.![^/]*!' >/dev/null; then
  echo "Restricted paths remain in rewritten history." >&2
  exit 1
fi

echo "Restricted paths are absent. Inspect refs before the explicit force push."
