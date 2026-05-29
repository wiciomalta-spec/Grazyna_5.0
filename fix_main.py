from pathlib import Path
import re

path = Path(r"E:\Grazyna_5.0\main.py")
code = path.read_text(encoding="utf-8")

# usuń tkinter importy
code = re.sub(r'^\s*import tkinter as tk.*$', '', code, flags=re.MULTILINE)
code = re.sub(r'^\s*from tkinter import .*$', '', code, flags=re.MULTILINE)

# usuń CAŁY GUI blok
code = re.sub(r'if __name__ == "__main__":[\s\S]*', '', code)

# dodaj CLI mapper + loop
cli = """

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
"""

code += "\n" + cli

path.write_text(code, encoding="utf-8")
print("✅ PATCH APPLIED")
