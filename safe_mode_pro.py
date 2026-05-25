import os
import sys
import time
import json
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import shutil
import tempfile

BASE = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(BASE, "data", "logs")
TOOLS = os.path.join(BASE, "tools")
PY = os.path.join(TOOLS, "PythonPortable")
MODULES = os.path.join(BASE, "modules")
LISTEN = os.path.join(BASE, "listen")
UPDATE = os.path.join(BASE, "update")

REPORT_JSON = os.path.join(LOG_DIR, "safe_report.json")
REPORT_HTML = os.path.join(LOG_DIR, "safe_report.html")

os.makedirs(LOG_DIR, exist_ok=True)

def log(msg, text=None):
    ts = time.strftime("[%Y-%m-%d %H:%M:%S]")
    line = f"{ts} {msg}"
    print(line)
    if text:
        text.insert(tk.END, line + "\n")
        text.see(tk.END)
        text.update()

def test_disk_read_write(text):
    log("[TEST] Disk read/write...", text)
    try:
        test_file = os.path.join(BASE, "disk_test.tmp")
        with open(test_file, "w") as f:
            f.write("TEST123")
        with open(test_file, "r") as f:
            data = f.read()
        os.remove(test_file)
        return {"disk_rw": "OK" if data == "TEST123" else "FAIL"}
    except Exception as e:
        return {"disk_rw": f"ERROR: {e}"}

def test_disk_speed(text):
    log("[TEST] Disk speed...", text)
    try:
        test_file = os.path.join(BASE, "speed_test.tmp")
        data = b"X" * (10 * 1024 * 1024)  # 10 MB
        start = time.time()
        with open(test_file, "wb") as f:
            f.write(data)
        write_time = time.time() - start

        start = time.time()
        with open(test_file, "rb") as f:
            f.read()
        read_time = time.time() - start

        os.remove(test_file)

        return {
            "write_MB_s": round(10 / write_time, 2),
            "read_MB_s": round(10 / read_time, 2)
        }
    except Exception as e:
        return {"disk_speed": f"ERROR: {e}"}

def test_permissions(text):
    log("[TEST] Permissions...", text)
    try:
        test_file = os.path.join(BASE, "perm_test.tmp")
        with open(test_file, "w") as f:
            f.write("OK")
        os.remove(test_file)
        return {"permissions": "WRITE OK"}
    except Exception as e:
        return {"permissions": f"ERROR: {e}"}

def test_python_portable(text):
    log("[TEST] PythonPortable...", text)
    python_exe = os.path.join(PY, "python.exe")
    tcl = os.path.join(PY, "tcl")
    if not os.path.isfile(python_exe):
        return {"python_portable": "MISSING python.exe"}
    if not os.path.isdir(tcl):
        return {"python_portable": "MISSING tcl (tkinter broken)"}
    return {"python_portable": "OK"}

def test_structure(text):
    log("[TEST] Structure...", text)
    required = [MODULES, LISTEN, UPDATE, LOG_DIR]
    result = {}
    for d in required:
        result[d] = "OK" if os.path.isdir(d) else "MISSING"
    return result

def test_main_launch(text):
    log("[TEST] main.py & launch.bat...", text)
    result = {}
    result["main.py"] = "OK" if os.path.isfile(os.path.join(BASE, "main.py")) else "MISSING"
    result["launch.bat"] = "OK" if os.path.isfile(os.path.join(BASE, "launch.bat")) else "MISSING"
    return result

def generate_html_report(data):
    html = "<html><body><h1>SAFE MODE PRO REPORT</h1><pre>"
    html += json.dumps(data, indent=4)
    html += "</pre></body></html>"
    with open(REPORT_HTML, "w", encoding="utf-8") as f:
        f.write(html)

class SafeModeProGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Grażyna SAFE MODE PRO")
        self.root.geometry("800x600")

        label = ttk.Label(self.root, text="SAFE MODE PRO – Diagnostyka i Raport", font=("Segoe UI", 14, "bold"))
        label.pack(pady=10)

        self.text = scrolledtext.ScrolledText(self.root, width=100, height=25)
        self.text.pack(padx=10, pady=10)

        btn = ttk.Button(self.root, text="Uruchom pełną diagnostykę", command=self.run_all)
        btn.pack(pady=10)

        self.root.mainloop()

    def run_all(self):
        self.text.delete("1.0", tk.END)
        log("=== SAFE MODE PRO START ===", self.text)

        report = {}
        report.update(test_disk_read_write(self.text))
        report.update(test_disk_speed(self.text))
        report.update(test_permissions(self.text))
        report.update(test_python_portable(self.text))
        report.update(test_structure(self.text))
        report.update(test_main_launch(self.text))

        with open(REPORT_JSON, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=4)

        generate_html_report(report)

        log("=== SAFE MODE PRO DONE ===", self.text)
        messagebox.showinfo("SAFE MODE PRO", "Diagnostyka zakończona.\nRaport zapisany jako JSON i HTML.")

if __name__ == "__main__":
    SafeModeProGUI()
