#!/usr/bin/env bash
# Shared helpers for agent-guardrails core guards.
# Runtime-neutral: no vendor-specific env vars or paths.

GUARDRAILS_KIT_ROOT="${GUARDRAILS_KIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GUARDRAILS_POLICY="${GUARDRAILS_POLICY:-$GUARDRAILS_KIT_ROOT/policy/default.policy.json}"

gr_block() {
  local guard="$1"
  local reason="$2"
  echo "BLOCKED by ${guard} (agent-guardrails): ${reason}" >&2
  exit 2
}

gr_warn() {
  echo "$1" >&2
}

gr_check_disabled() {
  if [ "${GUARDRAILS_DISABLE:-}" = "1" ]; then
    echo "GUARDRAILS_DISABLE=1: guard skipped (agent-guardrails)" >&2
    exit 0
  fi
}

# Returns 0 if override allows the given rule id.
gr_is_override_allowed() {
  local rule_id="$1"
  if [ "$rule_id" = "protected-files" ] && [ "${ALLOW_HOLY_FILE_EDIT:-}" = "1" ]; then
    return 0
  fi
  local allow="${GUARDRAILS_ALLOW:-}"
  [ -z "$allow" ] && return 1
  local IFS=','
  local item
  for item in $allow; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ "$item" = "$rule_id" ] && return 0
  done
  return 1
}

# Safe-path check for destructive commands targeting paths.
gr_is_safe_path() {
  local target="$1"
  local safepaths_file="${GUARDRAILS_KIT_ROOT}/policy/safepaths.txt"
  [ -z "$target" ] && return 1
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    case "$pattern" in
      ''|\#*) continue ;;
    esac
    # Safe-path policy entries intentionally use shell globs.
    # shellcheck disable=SC2254
    case "$target" in
      $pattern) return 0 ;;
    esac
  done < "$safepaths_file"
  return 1
}

# Extract path-like tokens from a command for safe-path checks.
gr_cmd_has_only_safe_targets() {
  local cmd="$1"
  local token
  for token in $cmd; do
    case "$token" in
      -*) continue ;;
      rm|find|git|dd|mkfs|shred) continue ;;
      of=*) continue ;;
      *)
        if gr_is_safe_path "$token"; then
          continue
        fi
        return 1
        ;;
    esac
  done
  return 0
}
