# Agent Guardrails Kit

Runtime-neutral **pre-execution safety hooks** for agentic coding: block destructive shell commands, stop live secrets from landing on disk, warn about PII, and protect source-of-truth files.

Works with **Claude Code**, **Codex**, **Cursor**, and **Windsurf** via thin adapters over a shared core.

No dependencies beyond `bash` and `python3` (stdlib only). Hooks read JSON from stdin and exit `2` to deny (or `0` to allow / soft-warn).

## Guards

| Guard | Fires on | Mode |
|---|---|---|
| `bash-guard` | Shell commands | **block** |
| `secret-scan` | Write / Edit / Patch content | **block** |
| `pii-warn` | Write / Edit content | **warn** (never blocks) |
| `protected-files` | Write / Edit to protected paths | **block** |

## Install

```bash
git clone https://github.com/xaversebastian/agent-guardrails-kit.git
cd agent-guardrails-kit
./install.sh /path/to/your/repo --runtime claude   # or codex, cursor, windsurf, all
# Self-contained copy that does not depend on this checkout afterwards:
./install.sh /path/to/your/repo --runtime codex --copy
```

Merge the matching `examples/<runtime>/hooks.json` into your repo hook config.

### CLI (direct)

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
  | ./cli/agent-guardrails --runtime claude --guard bash
```

## Configuration

**Project directory:** `GUARDRAILS_PROJECT_DIR` (falls back to `CLAUDE_PROJECT_DIR`, then `$PWD` in CLI layer).

**Protected files:** edit `policy/default.policy.json` → `protected_files.patterns`, or set `GUARDRAILS_PROTECTED_PATTERNS_FILE` to a glob list (one per line).

**Overrides (scoped per call):**

| Variable | Effect |
|---|---|
| `GUARDRAILS_ALLOW=protected-files` | Allow protected-file edit this call |
| `ALLOW_HOLY_FILE_EDIT=1` | Legacy alias for above |
| `GUARDRAILS_DISABLE=1` | Skip all guards (logged to stderr) |

**PII allowlists:** `PII_ALLOW_EMAIL_DOMAINS`, `PII_ALLOW_PHONES`, `PII_ALLOW_ADDRESSES`

## Architecture

```
core/           # Runtime-neutral guards (no CLAUDE_* references)
policy/         # default.policy.json + safepaths.txt
adapters/       # claude, codex, cursor, windsurf parsers + hook wrappers
cli/            # agent-guardrails entrypoint
```

## Security disclaimer

These hooks are a **best-effort safety net**, not a security boundary. They do not replace CI secret scanning, least-privilege tokens, or human approval for irreversible actions.

See [docs/threat-model.md](docs/threat-model.md) for scope and runtime limits.

## Migration

Upgrading from `claude-guardrails`? See [MIGRATION.md](MIGRATION.md).

## Tests

```bash
./test/run.sh --runtime all
./test/install-test.sh
```

## License

MIT — see [LICENSE](LICENSE).
