# AGENTS.md — agent-guardrails-kit

Tool-agnostic rules for maintaining this OSS repo.

## Session start

1. Read `PROJECT_STRUCTURE.md`
2. Read `AGENT_HANDOFF.md`
3. Read `README.md`

## Checks

```bash
./test/run.sh --runtime all
bash -n install.sh cli/agent-guardrails core/*.sh test/*.sh
```

## Constraints

- Core (`core/`) must stay free of `CLAUDE_*` and `.claude/` references
- Bash + python3 stdlib only in core/adapters
- No real secrets or PII in fixtures — synthetic tokens only
- Do not run `install.sh` against user repos without explicit approval

## Work style

- Atomic commits with clear messages
- No `--no-verify`, no force-push to main
- Append-only `AGENT_HANDOFF.md` for substantial changes

Codex is the default implementation surface; Claude/Cursor are review surfaces.
