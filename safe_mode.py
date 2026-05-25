import os
import sys
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import time
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
LOG_DIR = os.path.join(DATA_DIR, "logs")
TOOLS_DIR = os.path.join(BASE_DIR, "tools")
PY_PORTABLE = os.path.join(TOOLS_DIR, "PythonPortable")
MODULES_DIR = os.path.join(BASE_DIR, "modules")
LISTEN_DIR = os.path.join(BASE_DIR, "listen")
UPDATE_DIR = os.path.join(BASE_DIR, "update")
SYSTEM_LOG = os.path.join(LOG_DIR, "system.log")

REQUIRED_DIRS = [
    DATA_DIR,
    LOG_DIR,
    TOOLS_DIR,
    MODULES_DIR,
    LISTEN_DIR,
    UPDATE_DIR,
]

def log(msg: str, text_widget=None):
    ts = time.strftime("[%Y-%m-%d %H:%M:%S]")
    line = f"{ts} {msg}"
    print(line)
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(SYSTEM_LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass
    if text_widget is not None:
        text_widget.insert(tk.END, line + "\n")
        text_widget.see(tk.END)
        text_widget.update()

def check_dirs(text):
    log("Sprawdzam strukturę katalogów...", text)
    for d in REQUIRED_DIRS:
        if not os.path.isdir(d):
            log(f"[WARN] Brak katalogu: {d} – tworzę.", text)
            try:
                os.makedirs(d, exist_ok=True)
            except Exception as e:
                log(f"[ERROR] Nie mogę utworzyć {d}: {e}", text)
        else:
            log(f"[OK] Katalog istnieje: {d}", text)

def check_python_portable(text):
    log("Sprawdzam PythonPortable...", text)
    if not os.path.isdir(PY_PORTABLE):
        log("[ERROR] Brak katalogu tools/PythonPortable – PythonPortable nie jest zainstalowany.", text)
        return False

    python_exe = os.path.join(PY_PORTABLE, "python.exe")
    if not os.path.isfile(python_exe):
        log("[ERROR] Brak python.exe w PythonPortable.", text)
        return False

    tcl_dir = os.path.join(PY_PORTABLE, "tcl")
    if not os.path.isdir(tcl_dir):
        log("[WARN] Brak katalogu tcl – tkinter może nie działać.", text)
    else:
        log("[OK] Katalog tcl istnieje.", text)

    log("[OK] PythonPortable wygląda poprawnie.", text)
    return True

def check_main_and_launch(text):
    main_py = os.path.join(BASE_DIR, "main.py")
    launch_bat = os.path.join(BASE_DIR, "launch.bat")

    log("Sprawdzam main.py i launch.bat...", text)

    if not os.path.isfile(main_py):
        log("[ERROR] Brak main.py – system nie wystartuje normalnie.", text)
    else:
        log("[OK] main.py istnieje.", text)

    if not os.path.isfile(launch_bat):
        log("[WARN] Brak launch.bat – tworzę domyślny.", text)
        try:
            with open(launch_bat, "w", encoding="utf-8") as f:
                f.write(
                    "@echo off\n"
                    "\"%~dp0tools\\PythonPortable\\python.exe\" \"%~dp0main.py\"\n"
                    "pause\n"
                )
            log("[OK] Utworzono domyślny launch.bat.", text)
        except Exception as e:
            log(f"[ERROR] Nie mogę utworzyć launch.bat: {e}", text)
    else:
        log("[OK] launch.bat istnieje.", text)

def analyze_logs(text):
    log("Analizuję logi systemowe...", text)
    if not os.path.isfile(SYSTEM_LOG):
        log("[INFO] Brak system.log – nic do analizy.", text)
        return

    try:
        with open(SYSTEM_LOG, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()[-200:]
    except Exception as e:
        log(f"[ERROR] Nie mogę odczytać system.log: {e}", text)
        return

    error_count = 0
    for line in lines:
        if "ERROR" in line or "Traceback" in line:
            error_count += 1

    if error_count == 0:
        log("[OK] Brak oczywistych błędów w ostatnich logach.", text)
    else:
        log(f"[WARN] Wykryto {error_count} potencjalnych błędów w logach.", text)

def attempt_repair(text):
    log("Uruchamiam procedurę naprawczą...", text)
    check_dirs(text)
    ok_python = check_python_portable(text)
    check_main_and_launch(text)
    analyze_logs(text)

    if ok_python:
        log("[SAFE MODE] Środowisko wygląda na naprawione lub poprawne.", text)
    else:
        log("[SAFE MODE] PythonPortable jest uszkodzony lub niekompletny – rozważ ponowną instalację.", text)

class SafeModeGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Grażyna SAFE MODE")
        self.root.geometry("700x500")

        self.build_gui()
        self.root.after(500, self.auto_run)

        self.root.mainloop()

    def build_gui(self):
        label = ttk.Label(self.root, text="Grażyna SAFE MODE – diagnostyka i naprawa", font=("Segoe UI", 12, "bold"))
        label.pack(pady=10)

        self.text = scrolledtext.ScrolledText(self.root, width=80, height=20)
        self.text.pack(padx=10, pady=10)

        btn_frame = ttk.Frame(self.root)
        btn_frame.pack(pady=10)

        self.btn_diag = ttk.Button(btn_frame, text="Diagnostyka", command=self.run_diag)
        self.btn_diag.pack(side=tk.LEFT, padx=5)

        self.btn_repair = ttk.Button(btn_frame, text="Diagnostyka + Naprawa", command=self.run_repair)
        self.btn_repair.pack(side=tk.LEFT, padx=5)

        self.btn_exit = ttk.Button(btn_frame, text="Zamknij", command=self.root.destroy)
        self.btn_exit.pack(side=tk.LEFT, padx=5)

    def auto_run(self):
        # automatycznie odpala diagnostykę przy starcie
        self.run_repair()

    def run_diag(self):
        self.text.delete("1.0", tk.END)
        log("=== START DIAGNOSTYKI (SAFE MODE) ===", self.text)
        check_dirs(self.text)
        check_python_portable(self.text)
        check_main_and_launch(self.text)
        analyze_logs(self.text)
        log("=== KONIEC DIAGNOSTYKI ===", self.text)

    def run_repair(self):
        self.text.delete("1.0", tk.END)
        log("=== START DIAGNOSTYKI + NAPRAWY (SAFE MODE) ===", self.text)
        attempt_repair(self.text)
        log("=== KONIEC NAPRAWY ===", self.text)
        messagebox.showinfo("SAFE MODE", "Diagnostyka i naprawa zakończone.\nSprawdź logi powyżej.")

if __name__ == "__main__":
    SafeModeGUI()
