# AGENT_HANDOFF.md - claude-guardrails

STATUS: LIVE

Append-only handoff for the `claude-guardrails` repo. Keep entries short and
free of real secrets, real PII, user-level settings content, or private
workspace evidence.

## Current State

- This repo provides Claude Code PreToolUse guardrail hooks for Bash, secret
  scanning, PII soft-warnings, and protected source-of-truth files.
- Maintenance is file-first:
  `AGENTS.md -> PROJECT_STRUCTURE.md -> AGENT_HANDOFF.md`.
- Runtime hooks live under `hooks/`; sample wiring lives under
  `examples/settings.json`.
- `install.sh` changes other repos and must not be run without explicit user
  approval.

## Update Rule

Append an entry for any substantial repo-level workflow, structure, hook, or
safety change:

- Date · Tool · 1-line goal
- Changed paths
- Checks run
- Risks and open points
- Unsafe assumptions
- Rejected alternatives

## Log

### 2026-07-01 · Codex · repo agent surfaces

- **Goal:** Add file-first repo surfaces so Codex, Claude, and local LLMs can
  maintain `claude-guardrails` without relying on Claude-specific runtime
  state.
- **Changed paths:**
  - `AGENTS.md`
  - `PROJECT_STRUCTURE.md`
  - `AGENT_HANDOFF.md`
  - `tests/agent-surface-test.sh`
- **Checks run:**
  - TDD-RED: `tests/agent-surface-test.sh` failed correctly because
    `AGENTS.md` was missing.
  - TDD-GREEN: `tests/agent-surface-test.sh` PASS.
  - `bash -n install.sh hooks/*.sh tests/agent-surface-test.sh` PASS.
  - `git diff --check` PASS.
  - Synthetic JSON hook checks PASS:
    - harmless Bash command allowed
    - `git reset --hard` blocked with exit `2`
    - synthetic `sk_live_...` content blocked with exit `2`
    - `.env.example` placeholder allowed
    - `pii-warn.sh` allowed a synthetic test-domain email
    - `holy-file-guard.sh` blocked a protected temp file and allowed it with
      `ALLOW_HOLY_FILE_EDIT=1`
- **Open points:** `oss/dirigent` still has missing agent surfaces in the root
  workspace audit.
- **Unsafe assumptions:** This package documents maintenance workflow only; it
  does not change hook semantics or installation behavior.
- **Rejected alternatives:** No `install.sh` run, no `~/.claude` writes, no
  target repo `.claude/` writes, no release/publish action, and no real
  secrets or PII fixtures.

### 2026-07-10 · Codex · close destructive-command and template-secret bypasses

- **Goal:** Validate every `rm -rf` operand and scan example/template files while allowing unmistakable placeholders.
- **Changed paths:** `hooks/bash-guard.sh`, `hooks/secret-scan.sh`, `tests/hook-behavior-test.sh`, README and repo indexes.
- **Checks run:** behavior and agent-surface tests PASS; ShellCheck, Bash syntax and `git diff --check` PASS.
- **Risks/open:** Hooks remain best-effort and fail open only for malformed host payloads; no target installation or push.
- **Unsafe assumptions:** Synthetic key shapes represent detection canaries, not credentials.
- **Rejected alternatives:** No filename-wide secret allowlist and no single-safe-operand approval for mixed deletes.
