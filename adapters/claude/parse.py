#!/usr/bin/env python3
"""Claude Code stdin -> NormalizedEvent."""
import json, os, sys

def project_dir():
    return os.environ.get("GUARDRAILS_PROJECT_DIR") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

def collect_contents(ti):
    parts = []
    for k in ("content", "new_string"):
        v = ti.get(k)
        if isinstance(v, str):
            parts.append(v)
    edits = ti.get("edits")
    if isinstance(edits, list):
        for e in edits:
            if isinstance(e, dict) and isinstance(e.get("new_string"), str):
                parts.append(e["new_string"])
    patch = ti.get("patch") or ti.get("apply_patch")
    if isinstance(patch, str):
        parts.append(patch)
    return parts

def main():
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or {}
    event = {
        "runtime": "claude",
        "tool_name": data.get("tool_name", ""),
        "command": ti.get("command"),
        "contents": collect_contents(ti),
        "file_path": ti.get("file_path") or None,
        "cwd": os.getcwd(),
        "project_dir": project_dir(),
    }
    print(json.dumps(event))

if __name__ == "__main__":
    main()
