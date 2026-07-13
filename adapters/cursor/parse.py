#!/usr/bin/env python3
"""Cursor stdin -> NormalizedEvent (preToolUse:Write, beforeShellExecution)."""
import json, os, sys

def project_dir():
    return os.environ.get("GUARDRAILS_PROJECT_DIR") or os.getcwd()

def collect_contents(payload):
    parts = []
    for k in ("content", "new_string", "newContent", "text"):
        v = payload.get(k)
        if isinstance(v, str):
            parts.append(v)
    edits = payload.get("edits")
    if isinstance(edits, list):
        for e in edits:
            if isinstance(e, dict):
                for k in ("new_string", "newContent", "content"):
                    v = e.get(k)
                    if isinstance(v, str):
                        parts.append(v)
    return parts

def main():
    data = json.load(sys.stdin)
    ti = data.get("tool_input") or data.get("input") or data
    event = {
        "runtime": "cursor",
        "tool_name": data.get("tool_name", data.get("tool", data.get("hook_event_name", ""))),
        "command": ti.get("command") or data.get("command"),
        "contents": collect_contents(ti),
        "file_path": ti.get("file_path") or ti.get("path") or data.get("file_path") or None,
        "cwd": os.getcwd(),
        "project_dir": project_dir(),
    }
    print(json.dumps(event))

if __name__ == "__main__":
    main()
