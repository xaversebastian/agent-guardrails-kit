#!/usr/bin/env bash
# Install agent-guardrails-kit hooks into a target repo.
# Usage: ./install.sh <target-repo> [--runtime claude|codex|cursor|windsurf|all] [--copy]
set -euo pipefail

TARGET="${1:-}"
RUNTIME="all"
MODE="linked"

shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --runtime) RUNTIME="${2:-}"; shift 2 ;;
    --copy) MODE="copy"; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "usage: $0 <target-repo-dir> [--runtime claude|codex|cursor|windsurf|all] [--copy]" >&2
  exit 1
fi
if [ ! -d "$TARGET" ]; then
  echo "target dir does not exist: $TARGET" >&2
  exit 1
fi

KIT="$(cd "$(dirname "$0")" && pwd)"
CLI="$KIT/cli/agent-guardrails"
chmod +x "$CLI" "$KIT"/adapters/*/{hook.sh,parse.py} "$KIT"/core/*.sh

copy_runtime_support() {
  local rt="$1"
  local support="$TARGET/.agent-guardrails-kit"

  mkdir -p "$support/cli" "$support/core" "$support/policy" "$support/adapters/$rt"
  cp "$CLI" "$support/cli/agent-guardrails"
  cp "$KIT"/core/*.sh "$support/core/"
  cp "$KIT"/policy/* "$support/policy/"
  cp "$KIT/adapters/$rt/hook.sh" "$KIT/adapters/$rt/parse.py" "$support/adapters/$rt/"
  chmod +x \
    "$support/cli/agent-guardrails" \
    "$support"/core/*.sh \
    "$support/adapters/$rt/hook.sh" \
    "$support/adapters/$rt/parse.py"
}

install_hooks() {
  local rt="$1"
  local dest="$2"
  local hook_src="$KIT/adapters/$rt/hook.sh"
  mkdir -p "$dest"
  if [ "$MODE" = "copy" ]; then
    copy_runtime_support "$rt"
  fi
  for g in bash secret pii protected; do
    local name="agent-guardrails-${g}.sh"
    if [ "$MODE" = "copy" ]; then
      cat > "$dest/$name" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
export GUARDRAILS_GUARD=$g
TARGET_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
exec "\$TARGET_ROOT/.agent-guardrails-kit/adapters/$rt/hook.sh"
WRAPPER
    else
      cat > "$dest/$name" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
export GUARDRAILS_GUARD=$g
exec "$hook_src"
WRAPPER
    fi
    chmod +x "$dest/$name"
  done
  echo "installed $rt hooks ($MODE) -> $dest"
}

install_one() {
  local rt="$1"
  case "$rt" in
    claude) install_hooks claude "$TARGET/.claude/hooks" ;;
    codex) install_hooks codex "$TARGET/.codex/hooks" ;;
    cursor) install_hooks cursor "$TARGET/.cursor/hooks" ;;
    windsurf) install_hooks windsurf "$TARGET/.windsurf/hooks" ;;
    *)
      echo "unsupported runtime: $rt" >&2
      exit 1
      ;;
  esac
}

if [ "$RUNTIME" = "all" ]; then
  for rt in claude codex cursor windsurf; do
    install_one "$rt"
  done
else
  install_one "$RUNTIME"
fi

cat <<EOF

Done. Next steps:
  1. Merge examples/<runtime>/hooks.json into your repo hook config
  2. (optional) Copy agent-guardrails.policy.json patterns into policy/default.policy.json
  3. Start an agent session — guards are active via agent-guardrails CLI.
EOF
