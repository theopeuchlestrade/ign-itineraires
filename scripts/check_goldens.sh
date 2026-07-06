#!/bin/sh
set -eu

exec "$(dirname "$0")/update_goldens.sh" --check
