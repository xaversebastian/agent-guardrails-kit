#!/usr/bin/env bash
# PreToolUse hook for Bash commands.
# Blocks destructive / unsafe patterns. Exits 2 to deny the call.
# Reads JSON from stdin: { "tool_name": "Bash", "tool_input": { "command": "..." } }

set -euo pipefail

# Read full JSON from stdin
input=$(cat)

# Extract the command field via python (no jq dependency).
cmd=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("command", ""))
except Exception:
    pass
')

if [ -z "$cmd" ]; then
  exit 0
fi

block() {
  echo "BLOCKED by bash-guard.sh (claude-guardrails): $1" >&2
  echo "Command: $cmd" >&2
  exit 2
}

# Force-push to main / master / origin
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push[[:space:]].*(--force|--force-with-lease|-f([[:space:]]|$))'; then
  if printf '%s' "$cmd" | grep -qE '(main|master|origin)'; then
    block "force-push to main/master/origin requires explicit user confirmation"
  fi
fi

# --no-verify on commit/push (skips hooks)
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+(commit|push|merge|rebase)[[:space:]].*--no-verify'; then
  block "--no-verify bypasses pre-commit/pre-push hooks; needs explicit user OK"
fi

# Hard reset / destructive checkout
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  block "git reset --hard discards uncommitted work; ask first"
fi
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+(--|\.)'; then
  block "git checkout/restore on working tree discards uncommitted changes; ask first"
fi
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
  block "git clean -f removes untracked files; ask first"
fi

# Branch deletion (force)
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+branch[[:space:]]+-D'; then
  block "git branch -D force-deletes branches; ask first"
fi

# rm -rf without explicit safe paths
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)'; then
  # Allow common safe targets: ./node_modules, ./dist, ./.next, ./.astro, /tmp/*, ./.cache
  if printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rf][a-zA-Z]*[[:space:]]+(\./?(node_modules|dist|build|\.next|\.astro|\.cache|\.tmp|\.turbo|coverage)|/tmp/|/var/folders/)'; then
    : # safe, pass
  else
    block "rm -rf outside known safe paths (node_modules, dist, .next, .astro, .cache, .tmp, /tmp); ask first"
  fi
fi

# Direct .env deletion that often hides real intent
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])rm[[:space:]]+.*\.env([[:space:]]|$|\.)'; then
  block "deletion of .env files is dangerous; copy to backup or ask first"
fi

# Drop database / dangerous SQL
if printf '%s' "$cmd" | grep -qiE '(drop[[:space:]]+(database|schema|table)|truncate[[:space:]]+table)'; then
  block "destructive SQL detected; never run autonomously against production"
fi

# pass
exit 0
