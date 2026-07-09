#!/usr/bin/env bash
set -euo pipefail
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
export GUARDRAILS_KIT_ROOT="$KIT"
GUARD="${GUARDRAILS_GUARD:-all}"
exec "$KIT/cli/agent-guardrails" --runtime codex --guard "$GUARD" "$@"
