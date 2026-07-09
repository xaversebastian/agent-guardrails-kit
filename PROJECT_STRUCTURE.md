# PROJECT_STRUCTURE.md — agent-guardrails-kit

Runtime-neutral guardrail hooks for Codex, Claude Code, Cursor, and Windsurf.

## Repo shape

```text
.
├── README.md
├── MIGRATION.md
├── LICENSE
├── AGENTS.md
├── PROJECT_STRUCTURE.md
├── AGENT_HANDOFF.md
├── install.sh                    # --runtime <name|all>
├── cli/
│   └── agent-guardrails          # Main CLI: stdin → adapter → core
├── core/
│   ├── lib.sh                    # Shared helpers, override logic
│   ├── guard-bash.sh
│   ├── guard-secret.sh
│   ├── guard-pii.sh
│   └── guard-protected.sh
├── policy/
│   ├── default.policy.json
│   └── safepaths.txt
├── adapters/
│   ├── claude/{parse.py,hook.sh}
│   ├── codex/{parse.py,hook.sh}
│   ├── cursor/{parse.py,hook.sh}   # failClosed for writes
│   └── windsurf/{parse.py,hook.sh}
├── examples/
│   ├── claude/{hooks.json,protected-files.txt}
│   ├── codex/hooks.json
│   ├── cursor/hooks.json
│   └── windsurf/hooks.json
├── docs/
│   └── threat-model.md
├── test/
│   ├── run.sh                    # --runtime <name|all>
│   └── fixtures/{deny,allow,warn}/
└── .github/workflows/ci.yml
```

## Checks

- `./test/run.sh --runtime all`
- `rg -n 'CLAUDE_|\.claude/' core/` must be empty
