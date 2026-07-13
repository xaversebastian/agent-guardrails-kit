#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

TARGET="$TMP/target"
mkdir -p "$TARGET"

"$ROOT/install.sh" "$TARGET" --runtime codex --copy >/dev/null

WRAPPER="$TARGET/.codex/hooks/agent-guardrails-bash.sh"
[ -x "$WRAPPER" ] || { echo "FAIL: copy-mode wrapper missing" >&2; exit 1; }
[ -x "$TARGET/.agent-guardrails-kit/adapters/codex/hook.sh" ] \
  || { echo "FAIL: copied runtime support missing" >&2; exit 1; }

if grep -Fq "$ROOT" "$WRAPPER"; then
  echo "FAIL: --copy wrapper still depends on installer checkout" >&2
  exit 1
fi

printf '%s' '{"tool_name":"exec_command","tool_input":{"cmd":"git status"}}' \
  | "$WRAPPER" >/dev/null

echo "PASS install --copy is self-contained"
