#!/usr/bin/env bash
# PreToolUse hook for Write/Edit (and optionally Bash).
# Scans the new file content for high-confidence secret patterns and blocks (exit 2).
# Reads JSON from stdin: { "tool_name": "Write|Edit", "tool_input": { ... } }
#
# Wire it on Bash too (matcher "Bash") to also catch `printf/cp/echo >> file` bypasses.

set -euo pipefail

input=$(cat)

# Extract relevant content fields via python (no jq dependency):
#   Write -> tool_input.content
#   Edit  -> tool_input.new_string
#   Bash  -> tool_input.command
extracted=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    ti = data.get("tool_input", {})
    parts = []
    for k in ("content", "new_string", "command"):
        v = ti.get(k)
        if isinstance(v, str):
            parts.append(v)
    print("\n".join(parts))
except Exception:
    pass
')

file_path=$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("file_path", ""))
except Exception:
    pass
')

if [ -z "$extracted" ]; then
  exit 0
fi

# Example/template files are still scanned. Only unmistakably fake assignment
# values are removed before matching.
case "$file_path" in
  *.env.example|*template*|*TEMPLATE*)
    extracted=$(printf '%s' "$extracted" | python3 -c '
import re, sys

placeholder = re.compile(
    r"^(?:(?:CHANGE|REPLACE)(?:_?ME)?(?:_[A-Z0-9_]+)?|CHANGEME|REDACTED|"
    r"TODO|EXAMPLE|PLACEHOLDER|YOUR_[A-Z0-9_]+|X{3,}|"
    r"<[^>]+>|\$\{[^}]+\}|sk_test_x+|not-a-real-secret|from-keychain)$",
    re.IGNORECASE,
)

for line in sys.stdin:
    match = re.match(r"^\s*[A-Za-z_][A-Za-z0-9_]*\s*[:=]\s*([\"\x27]?)(.*?)\1\s*$", line.rstrip("\n"))
    if match and placeholder.fullmatch(match.group(2)):
        continue
    sys.stdout.write(line)
')
    ;;
esac

block() {
  echo "BLOCKED by secret-scan.sh (claude-guardrails): $1" >&2
  echo "File: $file_path" >&2
  echo "If this is a deliberate placeholder or example, rename to .env.example" >&2
  echo "or use a clearly fake value (e.g. 'sk_test_xxx', 'REDACTED')." >&2
  exit 2
}

# Stripe live secret keys
if printf '%s' "$extracted" | grep -qE 'sk_live_[A-Za-z0-9]{16,}'; then
  block "Stripe LIVE secret key detected (sk_live_...)"
fi

# Stripe live restricted keys
if printf '%s' "$extracted" | grep -qE 'rk_live_[A-Za-z0-9]{16,}'; then
  block "Stripe LIVE restricted key detected (rk_live_...)"
fi

# Stripe webhook secret (live)
if printf '%s' "$extracted" | grep -qE 'whsec_[A-Za-z0-9]{32,}'; then
  block "Stripe webhook secret detected (whsec_...)"
fi

# OpenAI / Anthropic-style keys with high-confidence prefix + length
if printf '%s' "$extracted" | grep -qE 'sk-(proj|ant|live)-[A-Za-z0-9_-]{20,}'; then
  block "API key detected (sk-proj/sk-ant/sk-live-...)"
fi
if printf '%s' "$extracted" | grep -qE 'sk-[A-Za-z0-9]{40,}'; then
  block "Long API key detected (sk-... 40+ chars)"
fi

# Supabase service-role / anon JWTs assigned to a service-role var
if printf '%s' "$extracted" | grep -qE 'SUPABASE_SERVICE_ROLE[A-Z_]*[[:space:]]*=[[:space:]]*"?eyJ[A-Za-z0-9._-]{40,}'; then
  block "Supabase service-role JWT assignment detected"
fi

# Private keys
if printf '%s' "$extracted" | grep -qE -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'; then
  block "private key block detected"
fi

# AWS access keys
if printf '%s' "$extracted" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  block "AWS access key id detected (AKIA...)"
fi

# Google API key shape
if printf '%s' "$extracted" | grep -qE 'AIza[0-9A-Za-z_-]{35}'; then
  block "Google API key detected (AIza...)"
fi

# Resend API keys
if printf '%s' "$extracted" | grep -qE '\bre_[A-Za-z0-9_-]{20,}'; then
  block "Resend API key detected (re_...)"
fi

# Notion integration tokens.
# Notion tokens are fixed-length base62 ([A-Za-z0-9], no _/-): legacy
# secret_<43>, new ntn_<~46>. {40,} + the pure base62 class avoids flagging
# harmless identifiers like `secret_someBooleanFlagName`.
if printf '%s' "$extracted" | grep -qE '\b(secret|ntn)_[A-Za-z0-9]{40,}'; then
  block "Notion token detected (secret_/ntn_...)"
fi

# GitHub personal access tokens (classic gh*_ + fine-grained github_pat_)
if printf '%s' "$extracted" | grep -qE '\bgh[pousr]_[A-Za-z0-9_]{20,}'; then
  block "GitHub token detected (gh*_...)"
fi
if printf '%s' "$extracted" | grep -qE '\bgithub_pat_[A-Za-z0-9_]{20,}'; then
  block "GitHub fine-grained PAT detected (github_pat_...)"
fi

# Supabase publishable/secret-looking keys
if printf '%s' "$extracted" | grep -qE '\bsb_(secret|publishable)_[A-Za-z0-9_-]{20,}'; then
  block "Supabase key detected (sb_secret_/sb_publishable_)"
fi

# High-risk env vars assigned a real-looking value.
# Extend this list with your own provider variables as needed.
if printf '%s' "$extracted" | grep -qE '\b(SERVICE_ROLE_KEY|SUPABASE_SERVICE_ROLE_KEY|STRIPE_SECRET_KEY|RESEND_API_KEY|ANTHROPIC_API_KEY|OPENAI_API_KEY|AZURE_OPENAI_KEY|NOTION_TOKEN|GITHUB_TOKEN|AWS_SECRET_ACCESS_KEY|GOOGLE_API_KEY|TWILIO_AUTH_TOKEN|DATABASE_URL|SECRET_KEY|PRIVATE_KEY)[[:space:]]*[:=][[:space:]]*["'\''"]?[A-Za-z0-9._~/+-]{16,}'; then
  block "known secret env var assigned a real-looking value"
fi

exit 0
