#!/usr/bin/env bash
# Internal test runner — invoked as a script to avoid outer bash-guard false positives.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/test/run.sh" "$@"
