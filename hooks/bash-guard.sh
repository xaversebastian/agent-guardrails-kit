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

# rm -rf: every operand must be allowlisted. One safe operand must not approve
# a mixed command that also removes an unrelated path.
unsafe_rm_operand=$(python3 - "$cmd" <<'PY'
import os
import shlex
import sys

command = sys.argv[1]
safe_roots = {
    "node_modules", "dist", "build", ".next", ".astro", ".cache",
    ".tmp", ".turbo", "coverage",
}

try:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|")
    lexer.whitespace_split = True
    tokens = list(lexer)
except ValueError:
    print("<unparseable-command>")
    raise SystemExit(0)

def is_separator(token: str) -> bool:
    return token and all(char in ";&|" for char in token)

def is_safe(path: str) -> bool:
    if path.startswith("/tmp/") or path.startswith("/var/folders/"):
        return True
    normalized = os.path.normpath(path)
    if os.path.isabs(normalized) or normalized in {".", ".."}:
        return False
    return normalized.split(os.sep, 1)[0] in safe_roots

index = 0
while index < len(tokens):
    if os.path.basename(tokens[index]) != "rm":
        index += 1
        continue

    args = []
    index += 1
    while index < len(tokens) and not is_separator(tokens[index]):
        args.append(tokens[index])
        index += 1

    recursive = False
    force = False
    operands = []
    options_done = False
    for arg in args:
        if not options_done and arg == "--":
            options_done = True
            continue
        if not options_done and arg.startswith("--"):
            recursive = recursive or arg == "--recursive"
            force = force or arg == "--force"
            continue
        if not options_done and arg.startswith("-") and arg != "-":
            flags = arg[1:]
            recursive = recursive or "r" in flags or "R" in flags
            force = force or "f" in flags
            continue
        operands.append(arg)

    if recursive and force:
        for operand in operands:
            if not is_safe(operand):
                print(operand)
                raise SystemExit(0)
PY
)
if [ -n "$unsafe_rm_operand" ]; then
  block "rm -rf has a non-allowlisted operand; every target must stay inside an approved build/cache directory or temporary path"
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
