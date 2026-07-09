# Threat Model (light)

## In scope

- Accidental destructive shell commands (force-push, mass delete, destructive SQL)
- Live API keys and secret shapes written to disk
- PII visibility in agent-written files (soft warn)
- Unintended edits to source-of-truth / strategy files

## Out of scope

- Adversarial obfuscation of commands or secrets
- Network exfiltration, compromised dependencies, malicious MCP servers
- GUI-only actions outside hook coverage
- Git history scanning (only pre-write / pre-shell)

## Runtime limits

| Runtime | Limitation |
|---|---|
| **Codex** | `apply_patch` / MCP hooks may be intermittent; `updatedInput` rewrites can bypass pre-checks |
| **Cursor** | Only `preToolUse:Write` blocks writes; post-write hooks are ineffective |
| **Claude** | `PreToolUse` coverage depends on matcher config |
| **Windsurf** | `tool_info` shape may drift; experimental adapter |

## Override policy

Non-overridable: live secret shapes, force-push, destructive SQL.

Scoped override via `GUARDRAILS_ALLOW=<rule-id>` per call. `GUARDRAILS_DISABLE=1` logs to stderr and skips all guards.

## Residual risk

Hooks are a **best-effort safety net**, not a security boundary. Use CI secret scanning, least-privilege tokens, and human approval for irreversible actions.
