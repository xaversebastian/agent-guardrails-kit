#!/usr/bin/env bash
# PreToolUse hook for Write/Edit.
# Blocks edits to high-impact "source of truth" files unless explicitly enabled.
#
# Protected paths are read from a config file (one glob per line, relative to the
# project root). Default location: $CLAUDE_PROJECT_DIR/.claude/holy-files.txt
# Override with HOLY_FILES_CONFIG. Lines starting with # are comments.
#
# To make an intentional edit, set ALLOW_HOLY_FILE_EDIT=1 for that call.
# If the config file is missing, this hook is a no-op (exit 0).

set -euo pipefail

input=$(cat)

file_path=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("file_path", ""))
except Exception:
    pass
')

if [ -z "$file_path" ]; then
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
config="${HOLY_FILES_CONFIG:-$project_dir/.claude/holy-files.txt}"

# No config -> nothing is protected.
[ -f "$config" ] || exit 0

# Path relative to project root for matching.
case "$file_path" in
  "$project_dir"/*) rel="${file_path#"$project_dir"/}" ;;
  *) rel="$file_path" ;;
esac

while IFS= read -r pattern || [ -n "$pattern" ]; do
  # Skip blank lines and comments
  case "$pattern" in
    ''|\#*) continue ;;
  esac
  # Trim trailing whitespace
  pattern="${pattern%"${pattern##*[![:space:]]}"}"
  # Glob match against the relative path
  # shellcheck disable=SC2254
  case "$rel" in
    $pattern)
      if [ "${ALLOW_HOLY_FILE_EDIT:-}" = "1" ]; then
        exit 0
      fi
      echo "BLOCKED by holy-file-guard.sh (claude-guardrails): protected file needs an explicit go-ahead." >&2
      echo "File: $rel" >&2
      echo "Matched pattern '$pattern' in $config" >&2
      echo "After deliberate review, set ALLOW_HOLY_FILE_EDIT=1 or edit it manually." >&2
      exit 2
      ;;
  esac
done < "$config"

exit 0
