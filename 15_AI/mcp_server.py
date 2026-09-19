#!/usr/bin/env python3
"""GRAŻYNA MCP safety facade.

This server intentionally exposes only read/plan operations. It does not perform
ECU writes, flashing, EEPROM erase, or IMMO execution.
"""
from __future__ import annotations
import json
import sys

TOOLS = {
    "read_ecu": "Read-only ECU identification/read contract",
    "read_vin": "Read VIN contract",
    "read_immo_status": "Read immobilizer status contract",
    "plan_immo_reset": "Plan only; no write",
    "diagnostics": "Read diagnostic status",
    "hardware_status": "Read KTAG/MPPS hardware status",
    "system_status": "Read GRAŻYNA system status",
}

def result(tool: str, args: dict) -> dict:
    if tool not in TOOLS:
        return {"ok": False, "error": "UNKNOWN_TOOL"}
    if tool == "plan_immo_reset":
        return {
            "ok": True,
            "tool": tool,
            "mode": "READ_ONLY",
            "writePerformed": False,
            "risk": "R4",
            "plan": ["identify ECU", "read IMMO status", "validate prerequisites", "request explicit approvals"],
        }
    return {
        "ok": True,
        "tool": tool,
        "mode": "READ_ONLY",
        "writePerformed": False,
        "status": "CONTRACT_ONLY",
        "args": args,
    }

def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            print(json.dumps(result(str(request.get("tool", "")), request.get("args", {})), ensure_ascii=False), flush=True)
        except Exception as exc:
            print(json.dumps({"ok": False, "error": type(exc).__name__}), flush=True)

if __name__ == "__main__":
    main()
