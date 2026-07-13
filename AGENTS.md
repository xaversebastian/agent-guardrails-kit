# AGENTS.md - claude-guardrails

This repo is a small Claude Code guardrail-hook suite. It is an independent
OSS/support-tool repo under `~/dev/oss/`.

## Inheritance

Read order:

1. `/Users/xaverfreytag/dev/AGENTS.md`
2. `/Users/xaverfreytag/dev/oss/AGENTS.md`
3. This file
4. `PROJECT_STRUCTURE.md`
5. `AGENT_HANDOFF.md`

## Scope

- Keep this repo dependency-light: bash hooks plus `python3`.
- Codex is the default maintenance agent for complete, clearly scoped,
  reversible repo tasks including implementation, tests, atomic commits and
  non-production pushes when assigned.
- Claude-specific PreToolUse hooks are the product surface, not a required
  runtime for maintaining this repo.
- Local LLMs must be able to recover context from files only:
  `AGENTS.md`, `PROJECT_STRUCTURE.md`, `AGENT_HANDOFF.md`, and `README.md`.

## Safety

- Do not run `install.sh` against another repo without explicit user approval.
- Do not write to `~/.claude`, target repo `.claude/`, or user-level settings
  during maintenance unless explicitly requested.
- Do not read `.env*`, credentials, generated output, or `.git/` internals.
- Test hook behavior with synthetic payloads only. Do not use real secrets or
  real personal data as fixtures.

## Checks

Run after substantive edits:

```bash
tests/agent-surface-test.sh
tests/hook-behavior-test.sh
bash -n install.sh hooks/*.sh tests/*.sh
```

For hook behavior, use synthetic stdin JSON and temporary directories only.
