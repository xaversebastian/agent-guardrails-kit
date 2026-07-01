#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"

fail() {
  printf 'FAIL agent-surface-test: %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [ -r "$path" ] || fail "missing readable file: $path"
}

require_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$path"; then
    fail "expected $path to contain: $needle"
  fi
}

require_file "$ROOT/AGENTS.md"
require_file "$ROOT/PROJECT_STRUCTURE.md"
require_file "$ROOT/AGENT_HANDOFF.md"

require_contains "$ROOT/AGENTS.md" "Codex is the default"
require_contains "$ROOT/AGENTS.md" "Claude-specific"
require_contains "$ROOT/PROJECT_STRUCTURE.md" "install.sh"
require_contains "$ROOT/PROJECT_STRUCTURE.md" "hooks/bash-guard.sh"
require_contains "$ROOT/PROJECT_STRUCTURE.md" "examples/settings.json"
require_contains "$ROOT/PROJECT_STRUCTURE.md" "tests/agent-surface-test.sh"
require_contains "$ROOT/AGENT_HANDOFF.md" "STATUS: LIVE"
require_contains "$ROOT/AGENT_HANDOFF.md" "AGENTS.md -> PROJECT_STRUCTURE.md -> AGENT_HANDOFF.md"

printf 'OK agent-surface-test\n'
