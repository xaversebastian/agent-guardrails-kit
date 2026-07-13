#!/usr/bin/env python3
"""Codex stdin -> NormalizedEvent."""
import json, os, sys

def project_dir():
    return os.environ.get("GUARDRAILS_PROJECT_DIR") or os.getcwd()

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
    for k in ("patch", "apply_patch"):
        v = ti.get(k)
        if isinstance(v, str):
            parts.append(v)
    return parts

def main():
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or data.get("input") or {}
    event = {
        "runtime": "codex",
        "tool_name": data.get("tool_name", data.get("tool", "")),
        "command": ti.get("command") or ti.get("cmd"),
        "contents": collect_contents(ti),
        "file_path": ti.get("file_path") or ti.get("path") or None,
        "cwd": os.getcwd(),
        "project_dir": project_dir(),
    }
    print(json.dumps(event))

if __name__ == "__main__":
    main()
