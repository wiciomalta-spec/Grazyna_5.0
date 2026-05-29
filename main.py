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
    ts = time.strftime("[%Y-%m-%d %H:%M:%S]")
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
if __name__ == "__main__":

    print("🚀 GRAŻYNA CLI MODE AKTYWNY")

    while True:
        try:
            cmd = input("🧠 Komenda: ").strip().lower()

            if not cmd:
                continue

            # normalizacja (usuwanie "grazyna")
            cmd = cmd.replace("grazyna", "").strip()

            suggestions = autocomplete_engine.suggest(cmd)
            meta = intent_parser.resolve(cmd, return_meta=True)

            action = meta.get("action")

            print("💡 Sugestie:", suggestions)
            print(f"🔍 match: {meta.get('match')} | score: {meta.get('score')}")

            if action:
                print("⚡ Akcja:", action)
                execute_action(action)
            else:
                print("❌ Nieznana komenda")

        except KeyboardInterrupt:
            print("👋 Zamykam system")
            break