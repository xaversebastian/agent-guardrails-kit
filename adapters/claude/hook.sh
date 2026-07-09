#!/usr/bin/env bash
# Claude adapter hook wrapper — delegates to agent-guardrails CLI.
set -euo pipefail
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
export GUARDRAILS_KIT_ROOT="$KIT"
GUARD="${GUARDRAILS_GUARD:-all}"
exec "$KIT/cli/agent-guardrails" --runtime claude --guard "$GUARD" "$@"
