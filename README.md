# claude-guardrails

A small suite of [Claude Code](https://docs.claude.com/en/docs/claude-code) **PreToolUse hooks**
that act as a safety net for agentic coding: block destructive shell commands, stop secrets and
keys from being written to disk, warn about leaking personal data, and protect your
source-of-truth files from accidental edits.

No dependencies beyond `bash` and `python3` (already on macOS/Linux). No jq required. Each hook
reads the tool-call JSON from stdin and exits `2` to deny a call (or `0` to allow / soft-warn).

## The hooks

| Hook | Fires on | What it does | Blocks? |
|---|---|---|---|
| `bash-guard.sh` | `Bash` | Blocks force-push to main/master/origin, `--no-verify`, `git reset --hard`, `git clean -f`, `git branch -D`, `rm -rf` outside safe paths (node_modules/dist/.next/…), `.env` deletion, and destructive SQL (`DROP`/`TRUNCATE`). | ✅ exit 2 |
| `secret-scan.sh` | `Write` `Edit` `Bash` | Scans new content for high-confidence secrets: Stripe (`sk_live_`/`whsec_`), OpenAI/Anthropic (`sk-ant-`/`sk-proj-`), Supabase, GitHub (`ghp_`/`github_pat_`), AWS (`AKIA`), Google (`AIza`), Resend, Notion, private-key blocks, and known secret env-vars assigned real values. Example/template files still block live-shaped values while allowing unmistakable placeholders. | ✅ exit 2 |
| `pii-warn.sh` | `Write` `Edit` | Soft-warns (stderr, never blocks) on phone numbers, foreign email addresses, and street addresses. The agent sees the warning and decides what to do. Allowlists are configurable. | ⚠️ exit 0 |
| `holy-file-guard.sh` | `Write` `Edit` | Blocks edits to files you mark as protected in `.claude/holy-files.txt` unless `ALLOW_HOLY_FILE_EDIT=1` is set. No config file → no-op. | ✅ exit 2 |

## Why

When you let an agent run shell commands and write files, the failure modes are predictable:
a `git push --force` to `main`, a real API key pasted into a committed file, a customer's phone
number ending up in a public repo, or your carefully-versioned pricing/strategy doc silently
rewritten. These hooks turn each of those into a hard stop (or a visible warning) at the moment
the tool call is attempted — before anything lands on disk or in history.

## Install

Clone this repo once, then link the hooks into any repo you work in:

```bash
git clone https://github.com/xaversebastian/claude-guardrails.git
cd claude-guardrails
./install.sh /path/to/your/repo          # symlinks hooks into <repo>/.claude/hooks/
# or: ./install.sh /path/to/your/repo --copy
```

The symlink mode is the point: keep one source of truth, and every repo you've linked picks up
changes automatically. Then merge [`examples/settings.json`](examples/settings.json) into your
repo's `.claude/settings.json` (it wires the matchers above).

### Manual wiring

If you prefer to wire it yourself, copy the hook files into `<repo>/.claude/hooks/`, `chmod +x`
them, and add the `PreToolUse` block from [`examples/settings.json`](examples/settings.json).

## Configuration

**Protected files** (`holy-file-guard.sh`) — list globs (relative to repo root), one per line, in
`.claude/holy-files.txt`. See [`examples/holy-files.txt`](examples/holy-files.txt). Override the
location with `HOLY_FILES_CONFIG`. To make a deliberate edit, run that turn with
`ALLOW_HOLY_FILE_EDIT=1`.

**PII allowlists** (`pii-warn.sh`) — comma-separated env vars, e.g. set inline in the hook command:

```
PII_ALLOW_EMAIL_DOMAINS="acme.com,acme.org"   # never warned
PII_ALLOW_PHONES="+1 555 0100"                # literal substrings to ignore
PII_ALLOW_ADDRESSES="Main Street 1"           # literal substrings to ignore
```

Phone and address detection are tuned for German formats — adjust the regexes in `pii-warn.sh`
for your locale.

**Extending secret-scan** — the env-var watchlist near the bottom of `secret-scan.sh` is a plain
alternation; add your own provider variables there.

## Notes

- Hooks are best-effort guards, not a security boundary. `secret-scan.sh` catches high-confidence
  *shapes*; it is not a replacement for a real secret scanner in CI or for `.gitignore` discipline.
- `bash-guard.sh`'s force-push rule blocks the command outright — when you genuinely need it, run
  it yourself outside the agent.
- All hooks fail open on malformed input (exit 0), so a parsing edge case never wedges your session.

## License

MIT — see [LICENSE](LICENSE).
