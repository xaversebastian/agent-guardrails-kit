#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

expect_exit() {
  local expected="$1"
  local hook="$2"
  local payload="$3"
  local actual

  set +e
  printf '%s' "$payload" | "$hook" >/dev/null 2>/dev/null
  actual=$?
  set -e

  if [ "$actual" -ne "$expected" ]; then
    printf 'FAIL: %s expected exit %s, got %s\n' "$(basename "$hook")" "$expected" "$actual" >&2
    exit 1
  fi
}

expect_exit 2 "$ROOT/hooks/bash-guard.sh" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf ./node_modules /Users/example/important"}}'
expect_exit 0 "$ROOT/hooks/bash-guard.sh" \
  '{"tool_name":"Bash","tool_input":{"command":"rm -rf ./node_modules ./dist"}}'

expect_exit 2 "$ROOT/hooks/secret-scan.sh" \
  '{"tool_name":"Write","tool_input":{"file_path":".env.example","content":"OPENAI_API_KEY=sk-proj-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}}'
expect_exit 0 "$ROOT/hooks/secret-scan.sh" \
  '{"tool_name":"Write","tool_input":{"file_path":".env.example","content":"OPENAI_API_KEY=REPLACE_ME"}}'

echo "PASS hook behavior"
