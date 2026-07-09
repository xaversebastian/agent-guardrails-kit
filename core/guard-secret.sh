#!/usr/bin/env bash
# Core secret scanner. Reads GR_CONTENT (newline-separated) and GR_FILE.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

gr_check_disabled

content="${GR_CONTENT:-}"
file_path="${GR_FILE:-}"

[ -z "$content" ] && exit 0

# S4: Allowlist only by file extension .example or .template
case "$file_path" in
  *.example|*.template) exit 0 ;;
esac

block_secret() {
  local reason="$1"
  echo "File: $file_path" >&2
  echo "If this is a deliberate placeholder, use .example or .template extension." >&2
  gr_block "secret-scan" "$reason"
}

# Live secrets are non-overridable
if printf '%s' "$content" | grep -qE 'sk_live_[A-Za-z0-9]{16,}'; then
  block_secret "Stripe LIVE secret key detected (sk_live_...)"
fi
if printf '%s' "$content" | grep -qE 'rk_live_[A-Za-z0-9]{16,}'; then
  block_secret "Stripe LIVE restricted key detected (rk_live_...)"
fi
if printf '%s' "$content" | grep -qE 'whsec_[A-Za-z0-9]{32,}'; then
  block_secret "Stripe webhook secret detected (whsec_...)"
fi
if printf '%s' "$content" | grep -qE 'sk-(proj|ant|live)-[A-Za-z0-9_-]{20,}'; then
  block_secret "API key detected (sk-proj/sk-ant/sk-live-...)"
fi
if printf '%s' "$content" | grep -qE 'sk-[A-Za-z0-9]{40,}'; then
  block_secret "Long API key detected (sk-... 40+ chars)"
fi
if printf '%s' "$content" | grep -qE 'SUPABASE_SERVICE_ROLE[A-Z_]*[[:space:]]*=[[:space:]]*"?eyJ[A-Za-z0-9._-]{40,}'; then
  block_secret "Supabase service-role JWT assignment detected"
fi
if printf '%s' "$content" | grep -qE -- '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'; then
  block_secret "private key block detected"
fi
if printf '%s' "$content" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  block_secret "AWS access key id detected (AKIA...)"
fi
if printf '%s' "$content" | grep -qE 'AIza[0-9A-Za-z_-]{35}'; then
  block_secret "Google API key detected (AIza...)"
fi
if printf '%s' "$content" | grep -qE '\bre_[A-Za-z0-9_-]{20,}'; then
  block_secret "Resend API key detected (re_...)"
fi
if printf '%s' "$content" | grep -qE '\b(secret|ntn)_[A-Za-z0-9]{40,}'; then
  block_secret "Notion token detected (secret_/ntn_...)"
fi
if printf '%s' "$content" | grep -qE '\bgh[pousr]_[A-Za-z0-9_]{20,}'; then
  block_secret "GitHub token detected (gh*_...)"
fi
if printf '%s' "$content" | grep -qE '\bgithub_pat_[A-Za-z0-9_]{20,}'; then
  block_secret "GitHub fine-grained PAT detected (github_pat_...)"
fi
if printf '%s' "$content" | grep -qE '\bsb_(secret|publishable)_[A-Za-z0-9_-]{20,}'; then
  block_secret "Supabase key detected (sb_secret_/sb_publishable_)"
fi
if printf '%s' "$content" | grep -qE '\b(SERVICE_ROLE_KEY|SUPABASE_SERVICE_ROLE_KEY|STRIPE_SECRET_KEY|RESEND_API_KEY|ANTHROPIC_API_KEY|OPENAI_API_KEY|AZURE_OPENAI_KEY|NOTION_TOKEN|GITHUB_TOKEN|AWS_SECRET_ACCESS_KEY|GOOGLE_API_KEY|TWILIO_AUTH_TOKEN|DATABASE_URL|SECRET_KEY|PRIVATE_KEY)[[:space:]]*[:=][[:space:]]*["'\''"]?[A-Za-z0-9._~/+-]{16,}'; then
  block_secret "known secret env var assigned a real-looking value"
fi

exit 0
