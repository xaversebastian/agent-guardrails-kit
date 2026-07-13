# Migration from claude-guardrails

## Summary

`claude-guardrails` is now **Agent Guardrails Kit** (`agent-guardrails-kit`). The product CLI is `agent-guardrails`.

## Claude Code users (no action required)

Existing `.claude/hooks/*.sh` symlinks continue to work if you re-run install:

```bash
./install.sh /path/to/your/repo --runtime claude
```

Legacy env vars are supported:

| Old | New | Status |
|---|---|---|
| `$CLAUDE_PROJECT_DIR` | `$GUARDRAILS_PROJECT_DIR` | Fallback chain in CLI |
| `ALLOW_HOLY_FILE_EDIT=1` | `GUARDRAILS_ALLOW=protected-files` | Alias still works |
| `.claude/holy-files.txt` | `policy/default.policy.json` | Auto-fallback via CLI |

## New runtime

```bash
./install.sh /path/to/your/repo --runtime cursor
# merge examples/cursor/hooks.json into .cursor/hooks.json
```

Repeat for `codex` or `windsurf`.

## Breaking changes (v1.0.0)

- Block messages say `(agent-guardrails)` instead of `(claude-guardrails)`
- Secret-scan allowlist: only `*.example` and `*.template` extensions (not `*template*` anywhere in path)
- Repo rename: clone from `agent-guardrails-kit` (GitHub redirect from old name)

## Verify migration

```bash
./test/run.sh --runtime all
```
