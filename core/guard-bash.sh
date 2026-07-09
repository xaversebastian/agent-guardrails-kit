#!/usr/bin/env bash
# Core bash guard. Reads GR_CMD from environment.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

gr_check_disabled

cmd="${GR_CMD:-}"
[ -z "$cmd" ] && exit 0

block_bash() {
  local rule_id="$1"
  local reason="$2"
  if gr_is_override_allowed "$rule_id"; then
    exit 0
  fi
  echo "Command: $cmd" >&2
  gr_block "bash-guard" "$reason"
}

# S1: Force-push including refspec (+main, +master)
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+push'; then
  force=0
  if printf '%s' "$cmd" | grep -qE '(--force|--force-with-lease|-f([[:space:]]|$))'; then
    force=1
  fi
  if printf '%s' "$cmd" | grep -qE '[[:space:]]\+[a-zA-Z0-9_./:-]+'; then
    force=1
  fi
  if [ "$force" -eq 1 ]; then
    if printf '%s' "$cmd" | grep -qE '(main|master|origin|HEAD)'; then
      block_bash "force-push" "force-push to main/master/origin requires explicit user confirmation"
    fi
  fi
fi

# --no-verify bypass
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+(commit|push|merge|rebase)[[:space:]].*--no-verify'; then
  block_bash "no-verify" "--no-verify bypasses pre-commit/pre-push hooks; needs explicit user OK"
fi

# Hard reset / destructive checkout
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  block_bash "git-reset-hard" "git reset --hard discards uncommitted work; ask first"
fi
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+(checkout|restore)[[:space:]]+(--|\.)'; then
  block_bash "git-checkout-discard" "git checkout/restore on working tree discards uncommitted changes; ask first"
fi
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
  block_bash "git-clean" "git clean -f removes untracked files; ask first"
fi
if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+branch[[:space:]]+-D'; then
  block_bash "git-branch-delete" "git branch -D force-deletes branches; ask first"
fi

# S2: rm with -r and -f flags in any order (combined or separate)
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])rm([[:space:]]|$)'; then
  has_r=0
  has_f=0
  if printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+.*-[a-zA-Z]*r'; then has_r=1; fi
  if printf '%s' "$cmd" | grep -qE 'rm[[:space:]]+.*-[a-zA-Z]*f'; then has_f=1; fi
  if [ "$has_r" -eq 1 ] && [ "$has_f" -eq 1 ]; then
    if gr_cmd_has_only_safe_targets "$cmd"; then
      : # safe path
    else
      block_bash "rm-recursive" "rm -r/-f outside known safe paths; ask first"
    fi
  fi
fi

# .env deletion
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])rm[[:space:]]+.*\.env([[:space:]]|$|\.)'; then
  block_bash "env-delete" "deletion of .env files is dangerous; copy to backup or ask first"
fi

# Destructive SQL (non-overridable)
if printf '%s' "$cmd" | grep -qiE '(drop[[:space:]]+(database|schema|table)|truncate[[:space:]]+table)'; then
  block_bash "destructive-sql" "destructive SQL detected; never run autonomously against production"
fi

# S3: Mass-delete family
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])find[[:space:]]+.*-delete'; then
  if printf '%s' "$cmd" | grep -qE 'find[[:space:]]+(\./?(node_modules|dist|build|\.next|\.astro|\.cache|\.tmp|\.turbo|coverage)(/|[[:space:]]|$)|/tmp/|/var/folders/)'; then
    : # safe find -delete target
  else
    block_bash "find-delete" "find -delete outside known safe paths; ask first"
  fi
fi

if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+rm[[:space:]]+(-[a-zA-Z]*r|--cached|[[:space:]]).*'; then
  if printf '%s' "$cmd" | grep -qE 'git[[:space:]]+rm[[:space:]]+(-[a-zA-Z]*r|-r|--cached)'; then
    if gr_cmd_has_only_safe_targets "$cmd"; then
      : # safe
    else
      block_bash "git-rm-recursive" "git rm -r removes tracked files; ask first"
    fi
  fi
fi

if printf '%s' "$cmd" | grep -qE 'dd[[:space:]]+.*of=/dev/'; then
  block_bash "dd-device" "dd to /dev/ is destructive; ask first"
fi

if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])(mkfs|mkfs\.[a-z0-9]+)([[:space:]]|$)'; then
  block_bash "mkfs" "mkfs formats storage; ask first"
fi

if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])shred([[:space:]]|$)'; then
  if gr_cmd_has_only_safe_targets "$cmd"; then
    : # safe
  else
    block_bash "shred" "shred permanently destroys data; ask first"
  fi
fi

exit 0
