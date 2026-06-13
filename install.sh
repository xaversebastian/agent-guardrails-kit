#!/usr/bin/env bash
# Install the claude-guardrails hooks into a target repo by symlinking them
# into <target>/.claude/hooks/. One source of truth, many repos: update this
# clone and every linked repo gets the change.
#
# Usage:
#   ./install.sh /path/to/your/repo
#   ./install.sh /path/to/your/repo --copy   # copy instead of symlink

set -euo pipefail

TARGET="${1:-}"
MODE="${2:-symlink}"

if [ -z "$TARGET" ]; then
  echo "usage: $0 <target-repo-dir> [--copy]" >&2
  exit 1
fi
if [ ! -d "$TARGET" ]; then
  echo "target dir does not exist: $TARGET" >&2
  exit 1
fi

SOT="$(cd "$(dirname "$0")/hooks" && pwd)"
DEST="$TARGET/.claude/hooks"
mkdir -p "$DEST"

for h in bash-guard.sh secret-scan.sh pii-warn.sh holy-file-guard.sh; do
  if [ "$MODE" = "--copy" ]; then
    cp "$SOT/$h" "$DEST/$h"
    echo "copied  $h"
  else
    ln -sf "$SOT/$h" "$DEST/$h"
    echo "linked  $h"
  fi
done

cat <<EOF

Done. Next steps:
  1. Merge examples/settings.json into $TARGET/.claude/settings.json
  2. (optional) Copy examples/holy-files.txt to $TARGET/.claude/holy-files.txt and edit it
  3. Start a Claude Code session in $TARGET — the guards are now active.
EOF
