#!/usr/bin/env bash
# Core protected-files guard. Reads GR_FILE and GR_PROJECT_DIR.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

gr_check_disabled

file_path="${GR_FILE:-}"
project_dir="${GR_PROJECT_DIR:-}"

[ -z "$file_path" ] && exit 0
[ -z "$project_dir" ] && project_dir="$(pwd)"

# Load patterns from policy JSON via python stdlib
patterns=$(python3 - "$GUARDRAILS_POLICY" <<'PY'
import json, sys

policy_path = sys.argv[1]
patterns = []
try:
    with open(policy_path) as f:
        data = json.load(f)
    patterns = data.get("policies", {}).get("protected_files", {}).get("patterns", [])
except Exception:
    pass
for p in patterns:
    print(p)
PY
)

# Optional extra patterns file (set by adapter/install layer, not hardcoded vendor paths)
if [ -n "${GUARDRAILS_PROTECTED_PATTERNS_FILE:-}" ] && [ -f "${GUARDRAILS_PROTECTED_PATTERNS_FILE}" ]; then
  extra=$(grep -vE '^\s*($|#)' "${GUARDRAILS_PROTECTED_PATTERNS_FILE}" || true)
  patterns=$(printf '%s\n%s' "$patterns" "$extra")
fi

[ -z "$patterns" ] && exit 0

case "$file_path" in
  "$project_dir"/*) rel="${file_path#"$project_dir"/}" ;;
  *) rel="$file_path" ;;
esac

while IFS= read -r pattern || [ -n "$pattern" ]; do
  [ -z "$pattern" ] && continue
  # Patterns are policy-defined globs, not literal strings.
  # shellcheck disable=SC2254
  case "$rel" in
    $pattern)
      if gr_is_override_allowed "protected-files"; then
        exit 0
      fi
      echo "BLOCKED by protected-files (agent-guardrails): protected file needs an explicit go-ahead." >&2
      echo "File: $rel" >&2
      echo "Matched pattern '$pattern'" >&2
      echo "Set GUARDRAILS_ALLOW=protected-files or legacy ALLOW_HOLY_FILE_EDIT=1 after review." >&2
      exit 2
      ;;
  esac
done <<< "$patterns"

exit 0
