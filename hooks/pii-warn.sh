#!/usr/bin/env bash
# PreToolUse hook for Write/Edit — non-blocking PII soft-warn.
# Scans new file content for high-confidence PII heuristics and warns to stderr.
# Always exits 0 (never blocks). The agent sees the warning in the tool result
# and decides what to do (pseudonymise, ask the user, proceed).
#
# Reads JSON from stdin: { "tool_name": "Write|Edit", "tool_input": { ... } }
#
# Configure allowlists via environment variables (e.g. in .claude/settings.json
# under the hook's "env", or exported in your shell):
#   PII_ALLOW_EMAIL_DOMAINS="acme.com,acme.org"   # comma-separated, never warned
#   PII_ALLOW_PHONES="+1 555 0100,+49 30 1234567" # comma-separated literal substrings
#   PII_ALLOW_ADDRESSES="Main Street 1"           # comma-separated literal substrings
#
# NOTE: phone/address detection is tuned for German formats. Adjust the regexes
# below for your locale.

set -uo pipefail
# Note: no `-e` — we want soft-warn, never crash the hook.

input=$(cat)

extracted=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    ti = data.get("tool_input", {})
    parts = []
    for k in ("content", "new_string"):
        v = ti.get(k)
        if isinstance(v, str):
            parts.append(v)
    print("\n".join(parts))
except Exception:
    pass
' 2>/dev/null)

file_path=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("file_path", ""))
except Exception:
    pass
' 2>/dev/null)

if [ -z "$extracted" ]; then
  exit 0
fi

# Skip generated / binary / lock files
case "$file_path" in
  */node_modules/*|*/.git/*|*/dist/*|*/.next/*|*/build/*) exit 0 ;;
  *.lock|*.lockb|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.zip) exit 0 ;;
esac

warn() {
  local kind="$1"
  local match="$2"
  echo "PII-WARN ($kind): '$match' in $file_path" >&2
}

# Filter a newline-separated hit list against a comma-separated allowlist of
# literal substrings (env var). Echoes the surviving hits.
filter_allow() {
  local hits="$1"
  local allow="$2"
  [ -z "$allow" ] && { printf '%s' "$hits"; return; }
  local IFS=','
  local a
  for a in $allow; do
    a="$(printf '%s' "$a" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$a" ] && continue
    hits="$(printf '%s' "$hits" | grep -vF "$a" || true)"
  done
  printf '%s' "$hits"
}

# Phone numbers (German-style +49... or 0...)
phone_hits=$(printf '%s' "$extracted" \
  | grep -oE '(\+49[ -]?[0-9]{2,4}[ -]?[0-9]{5,9}|0[0-9]{2,4}[ -/]?[0-9]{5,9})' \
  | head -10)
phone_hits=$(filter_allow "$phone_hits" "${PII_ALLOW_PHONES:-}" | head -3)
if [ -n "$phone_hits" ]; then
  while IFS= read -r m; do [ -n "$m" ] && warn "phone" "$m"; done <<< "$phone_hits"
fi

# Email addresses — always-allowed standard test domains, plus user allowlist.
default_email_allow='@(example\.(com|org|net)|test\.com|localhost)'
email_allow="$default_email_allow"
if [ -n "${PII_ALLOW_EMAIL_DOMAINS:-}" ]; then
  extra=$(printf '%s' "$PII_ALLOW_EMAIL_DOMAINS" \
    | sed -e 's/[[:space:]]//g' -e 's/\./\\./g' -e 's/,/|/g')
  [ -n "$extra" ] && email_allow="$email_allow|@($extra)"
fi
email_hits=$(printf '%s' "$extracted" \
  | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
  | grep -vE "$email_allow" \
  | head -3)
if [ -n "$email_hits" ]; then
  while IFS= read -r m; do [ -n "$m" ] && warn "email" "$m"; done <<< "$email_hits"
fi

# Street address pattern (German-style: street name + number)
address_hits=$(printf '%s' "$extracted" \
  | grep -oE '\b[A-ZÄÖÜ][a-zäöüß]+(straße|str\.|weg|allee|platz|gasse)[ -]+[0-9]+[a-z]?\b' \
  | head -10)
address_hits=$(filter_allow "$address_hits" "${PII_ALLOW_ADDRESSES:-}" | head -3)
if [ -n "$address_hits" ]; then
  while IFS= read -r m; do [ -n "$m" ] && warn "address" "$m"; done <<< "$address_hits"
fi

# Soft-warn is non-blocking
exit 0
