# --- PATH BOOTSTRAP ---
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# --- CORE IMPORTS ---
from core.autocomplete import AutocompleteEngine
from core.intent_parser import IntentParser

autocomplete_engine = AutocompleteEngine()
intent_parser = IntentParser()

# --- SYSTEM IMPORTS ---
import subprocess
import time

# =========================
# LOG
# =========================
def log(msg: str):
#     ts = time.strftime("[%Y-%m-%d %H:%M:%S]")
    print(f"{ts} {msg}")

# =========================
# ACTION EXECUTION
# =========================
def execute_action(action: str):
    log(f"[ACTION] {action}")

    if action == "open_terminal":
        subprocess.Popen(["powershell.exe"])

    elif action == "restart_system":
        os.execv(sys.executable, [sys.executable] + sys.argv)

    elif action == "open_gpt":
        print("🤖 GPT opened")

    elif action == "open_data_analysis":
        print("📊 Analysis opened")

    elif action == "disable_voice":
        print("🔇 Voice OFF")

    elif action == "enable_voice":
        print("🔊 Voice ON")

    else:
        print("⚠️ Unknown action")


# =========================
# CLI ENTRYPOINT
# =========================



# ===== CLI ACTION EXECUTION =====
def execute_action(action):
    import subprocess, sys, os

    actions = {
        "open_terminal": lambda: subprocess.Popen(["powershell.exe"]),
        "restart_system": lambda: os.execv(sys.executable, [sys.executable] + sys.argv),
        "open_gpt": lambda: print("[ACTION] GPT opened"),
        "open_data_analysis": lambda: print("[ACTION] Analysis opened"),
        "disable_voice": lambda: print("[ACTION] Voice OFF"),
        "enable_voice": lambda: print("[ACTION] Voice ON"),
    }

    if action in actions:
        actions[action]()
    else:
        print(f"[WARN] Unknown action: {action}")


# ===== FINAL CLI ENTRYPOINT =====



# ===== CLI ACTION EXECUTION =====
def execute_action(action):
    import subprocess, sys, os

    actions = {
        "open_terminal": lambda: subprocess.Popen(["powershell.exe"]),
        "restart_system": lambda: os.execv(sys.executable, [sys.executable] + sys.argv),
        "open_gpt": lambda: print("[ACTION] GPT opened"),
        "open_data_analysis": lambda: print("[ACTION] Analysis opened"),
        "disable_voice": lambda: print("[ACTION] Voice OFF"),
        "enable_voice": lambda: print("[ACTION] Voice ON"),
    }

    if action in actions:
        actions[action]()
    else:
        print(f"[WARN] Unknown action: {action}")


# ===== FINAL CLI ENTRYPOINT =====
if __name__ == "__main__":

    print("🚀 GRAŻYNA CLI MODE AKTYWNY")

    while True:
        try:
            cmd = input("🧠 Komenda: ").strip()

            if not cmd:
                continue

            suggestions = autocomplete_engine.suggest(cmd)
            action = intent_parser.resolve(cmd)

            print("💡 Sugestie:", suggestions)

            if action:
                print("⚡ Akcja:", action)
                execute_action(action)
            else:
                print("❌ Nieznana komenda")

        except KeyboardInterrupt:
            print("👋 Zamykam system")
            break
