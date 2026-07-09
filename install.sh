#!/usr/bin/env bash
# Install agent-guardrails-kit hooks into a target repo.
# Usage: ./install.sh <target-repo> [--runtime claude|codex|cursor|windsurf|all] [--copy]
set -euo pipefail

TARGET="${1:-}"
RUNTIME="all"

shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --runtime) RUNTIME="${2:-}"; shift 2 ;;
    --copy) shift ;;
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
chmod +x "$CLI" "$KIT"/adapters/*/{hook.sh,parse.py} "$KIT"/core/*.sh 2>/dev/null || true

install_hooks() {
  local rt="$1"
  local dest="$2"
  local hook_src="$KIT/adapters/$rt/hook.sh"
  mkdir -p "$dest"
  for g in bash secret pii protected; do
    local name="agent-guardrails-${g}.sh"
    cat > "$dest/$name" <<WRAPPER
#!/usr/bin/env bash
export GUARDRAILS_GUARD=$g
exec "$hook_src"
WRAPPER
    chmod +x "$dest/$name"
  done
  echo "installed $rt hooks -> $dest"
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
