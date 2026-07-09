#!/usr/bin/env bash
# Core PII soft-warn guard. Always exits 0.
set -uo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

gr_check_disabled

content="${GR_CONTENT:-}"
file_path="${GR_FILE:-}"

[ -z "$content" ] && exit 0

case "$file_path" in
  */node_modules/*|*/.git/*|*/dist/*|*/.next/*|*/build/*) exit 0 ;;
  *.lock|*.lockb|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.zip) exit 0 ;;
esac

warn_pii() {
  gr_warn "PII-WARN ($1): '$2' in ${file_path:-<unknown>}"
}

filter_allow() {
  local hits="$1"
  local allow="$2"
  [ -z "$allow" ] && { printf '%s' "$hits"; return; }
  local IFS=','
  local a
  for a in $allow; do
    a="${a#"${a%%[![:space:]]*}"}"
    a="${a%"${a##*[![:space:]]}"}"
    [ -z "$a" ] && continue
    hits="$(printf '%s' "$hits" | grep -vF "$a" || true)"
  done
  printf '%s' "$hits"
}

phone_hits=$(printf '%s' "$content" \
  | grep -oE '(\+49[ -]?[0-9]{2,4}[ -]?[0-9]{5,9}|0[0-9]{2,4}[ -/]?[0-9]{5,9})' \
  | head -10)
phone_hits=$(filter_allow "$phone_hits" "${PII_ALLOW_PHONES:-}" | head -3)
if [ -n "$phone_hits" ]; then
  while IFS= read -r m; do [ -n "$m" ] && warn_pii "phone" "$m"; done <<< "$phone_hits"
fi

default_email_allow='@(example\.(com|org|net)|test\.com|localhost)'
email_allow="$default_email_allow"
if [ -n "${PII_ALLOW_EMAIL_DOMAINS:-}" ]; then
  extra=$(printf '%s' "$PII_ALLOW_EMAIL_DOMAINS" \
    | sed -e 's/[[:space:]]//g' -e 's/\./\\./g' -e 's/,/|/g')
  [ -n "$extra" ] && email_allow="$email_allow|@($extra)"
fi
email_hits=$(printf '%s' "$content" \
  | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
  | grep -vE "$email_allow" \
  | head -3)
if [ -n "$email_hits" ]; then
  while IFS= read -r m; do [ -n "$m" ] && warn_pii "email" "$m"; done <<< "$email_hits"
fi

address_hits=$(printf '%s' "$content" \
  | grep -oE '\b[A-ZÄÖÜ][a-zäöüß]+(straße|str\.|weg|allee|platz|gasse)[ -]+[0-9]+[a-z]?\b' \
  | head -10)
address_hits=$(filter_allow "$address_hits" "${PII_ALLOW_ADDRESSES:-}" | head -3)
if [ -n "$address_hits" ]; then
  while IFS= read -r m; do [ -n "$m" ] && warn_pii "address" "$m"; done <<< "$address_hits"
fi

exit 0
