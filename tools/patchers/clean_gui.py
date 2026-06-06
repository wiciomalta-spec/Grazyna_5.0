from pathlib import Path

path = Path(r"E:\Grazyna_5.0\main.py")
code = path.read_text(encoding="utf-8")

# 🔥 Wyłącz GUI klasy (nie kasuj — tylko dezaktywuj)
code = code.replace("class ChatInterface:", "# DISABLED GUI class ChatInterface:")
code = code.replace("class GrazynaSystem:", "# DISABLED GUI class GrazynaSystem:")

# 🔥 Zabezpieczenie funkcji GUI
code = code.replace("messagebox.", "# messagebox.")
code = code.replace("ttk.", "# ttk.")
code = code.replace("tk.", "# tk.")

path.write_text(code, encoding="utf-8")

print("✅ GUI references disabled safely")
