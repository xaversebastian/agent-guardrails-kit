# AGENT_HANDOFF.md — agent-guardrails-kit

STATUS: LIVE

## Current state

- Full refactor from `claude-guardrails` to runtime-neutral Agent Guardrails Kit
- Core/adapter split with CLI entrypoint
- FN S1–S4 closed, fixture suite + CI scaffold

## Log

### 2026-07-09 · Cursor · agent-guardrails-kit v1 refactor

- **Goal:** Complete P0+P1 refactor per consolidated Decision-Spec
- **Changed paths:** core/, policy/, adapters/, cli/, test/, examples/, docs/, install.sh, README.md, MIGRATION.md, CI
- **Checks run:** `./test/run.sh --runtime all` PASS (23/23, FN=0, FP=0); shellcheck OK; core neutrality OK
- **Unsafe assumptions:** Windsurf/Codex hook JSON shapes based on spec, not live API verification
- **Rejected alternatives:** YAML policy parser (kept JSON + txt regex files)

### 2026-07-10 · Codex · installer and template-secret hardening

- **Goal:** Make `--copy` self-contained and keep live-shaped secrets blocked in example/template files.
- **Changed paths:** `install.sh`, `core/guard-secret.sh`, installer and guard fixtures/tests, README and repo indexes.
- **Checks run:** `./test/run.sh --runtime all` PASS (25/25, FN=0, FP=0); `./test/install-test.sh` PASS; ShellCheck, Bash syntax, core neutrality and `git diff --check` PASS.
- **Risks/open:** Runtime payload shapes remain experimental where documented; no install into user repos and no push.
- **Unsafe assumptions:** None for copy-mode self-containment; the test executes the copied Codex wrapper from a temporary target.
- **Rejected alternatives:** No absolute path back to the installer checkout and no blanket template bypass retained.
