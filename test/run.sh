#!/usr/bin/env bash
# Fixture test runner for agent-guardrails-kit.
# Usage: ./test/run.sh [--runtime claude|codex|cursor|windsurf|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_FILTER="${1:-}"
if [ "$RUNTIME_FILTER" = "--runtime" ]; then
  RUNTIME_FILTER="${2:-all}"
else
  RUNTIME_FILTER="all"
fi

CLI="$ROOT/cli/agent-guardrails"
chmod +x "$CLI" "$ROOT"/core/*.sh "$ROOT"/adapters/*/{hook.sh,parse.py} 2>/dev/null || true

pass=0
fail=0
fp=0
fn=0

run_fixture() {
  local file="$1"
  local name runtime guard expect_exit stdin
  name=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["name"])' "$file")
  runtime=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["runtime"])' "$file")
  guard=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["guard"])' "$file")
  expect_exit=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["expect_exit"])' "$file")

  if [ "$RUNTIME_FILTER" != "all" ] && [ "$RUNTIME_FILTER" != "$runtime" ]; then
    return 0
  fi

  stdin=$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))["stdin"]))' "$file")

  # Optional per-fixture env
  eval "$(python3 -c '
import json, sys, shlex
d = json.load(open(sys.argv[1]))
env = d.get("env", {})
for k, v in env.items():
    if k == "GUARDRAILS_POLICY" and v == "POLICY_OVERRIDE":
        v = sys.argv[2] + "/test/fixtures/policy-test.json"
    print(f"export {k}={shlex.quote(str(v))}")
' "$file" "$ROOT")"

  set +e
  printf '%s' "$stdin" | GUARDRAILS_KIT_ROOT="$ROOT" "$CLI" --runtime "$runtime" --guard "$guard" >/dev/null 2>/dev/null
  rc=$?
  set -e

  if [ "$rc" -eq "$expect_exit" ]; then
    pass=$((pass + 1))
    printf 'PASS %s (%s/%s exit %s)\n' "$name" "$runtime" "$guard" "$rc"
  else
    fail=$((fail + 1))
    if [ "$expect_exit" -eq 2 ] && [ "$rc" -eq 0 ]; then
      fn=$((fn + 1))
    fi
    if [ "$expect_exit" -eq 0 ] && [ "$rc" -eq 2 ]; then
      fp=$((fp + 1))
    fi
    printf 'FAIL %s (%s/%s): expected exit %s, got %s\n' "$name" "$runtime" "$guard" "$expect_exit" "$rc" >&2
  fi
}

printf '== shellcheck ==\n'
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -e SC1091,SC2034,SC2254 \
    "$ROOT"/core/*.sh "$ROOT"/cli/agent-guardrails "$ROOT"/install.sh "$ROOT"/test/run.sh "$ROOT"/adapters/*/hook.sh
  printf 'shellcheck: OK\n'
else
  printf 'shellcheck: SKIP (not installed)\n'
fi

printf '== core neutrality ==\n'
if rg -n 'CLAUDE_|\.claude/' "$ROOT/core/" 2>/dev/null; then
  printf 'FAIL: CLAUDE_ or .claude/ found in core/\n' >&2
  exit 1
fi
printf 'core neutrality: OK\n'

printf '== fixtures ==\n'
for dir in deny allow warn; do
  for f in "$ROOT/test/fixtures/$dir"/*.json; do
    [ -f "$f" ] || continue
    run_fixture "$f"
  done
done

total=$((pass + fail))
printf '\nResults: %s passed, %s failed (FN=%s FP=%s) of %s\n' "$pass" "$fail" "$fn" "$fp" "$total"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
