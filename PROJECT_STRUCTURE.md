# PROJECT_STRUCTURE.md - claude-guardrails

`claude-guardrails` is an independent OSS/support-tool repo for Claude Code
PreToolUse safety hooks. It should stay small, dependency-light, and
maintainable without relying on Claude runtime state.

## Session Entry

1. Read `AGENTS.md`.
2. Read this file.
3. Read `AGENT_HANDOFF.md`.
4. Read `README.md` for user-facing behavior.
5. Check git status before editing and do not touch foreign dirty changes.

## Repo Shape

```text
.
├── README.md                  # User-facing install, hook, and privacy notes
├── LICENSE                    # MIT license
├── AGENTS.md                  # Tool-agnostic agent rules for this repo
├── PROJECT_STRUCTURE.md       # This index
├── AGENT_HANDOFF.md           # Append-only repo handoff
├── .gitignore                 # OS/tooling ignores
├── install.sh                 # Installs/copies hooks into a target repo
├── hooks/
│   ├── bash-guard.sh          # Blocks destructive shell commands
│   ├── secret-scan.sh         # Blocks high-confidence secret writes
│   ├── pii-warn.sh            # Soft-warns on PII heuristics
│   └── holy-file-guard.sh     # Blocks protected source-of-truth edits
├── examples/
│   ├── settings.json          # Example Claude Code hook wiring
│   └── holy-files.txt         # Example protected-file glob list
└── tests/
    └── agent-surface-test.sh  # File-first agent surface regression test
```

## Checks

- `tests/agent-surface-test.sh`
- `bash -n install.sh hooks/*.sh tests/agent-surface-test.sh`
- `hooks/bash-guard.sh`
- Synthetic stdin JSON checks for hook allow/block behavior when hook behavior
  changes.

## Exclusions

Do not content-audit or commit:

- `.git/`
- `.env*` files or credentials
- generated outputs, archives, or worktrees
- real secrets or real personal data in fixtures

Allowed checks for excluded paths: existence, counts, sizes, and broad
classification only.

## Tooling Contract

- Repo maintenance must not require Claude hooks, Claude memory, cloud memory,
  MCPs, or SessionStart behavior.
- `examples/settings.json` is sample wiring only. Do not modify user-level
  Claude settings or install hooks into target repos unless explicitly asked.
- Hook behavior tests must use synthetic payloads and temporary directories.
