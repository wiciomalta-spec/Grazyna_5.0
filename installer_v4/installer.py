import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import os
import subprocess
import shutil
import json
import threading
import time
import psutil

# =========================
# KONFIGURACJA
# =========================

PYTHON_URL = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
PYTHON_INSTALLER = os.path.join(os.getenv("TEMP"), "python-3.10.11-amd64.exe")
PYTHON_TARGET = "C:\\Python310"

GRAZYNA_VERSION = "5.1"
INSTALL_FOLDER_NAME = f"Grazyna_{GRAZYNA_VERSION}"

LANGUAGES = {
    "PL": {
        "title": "Instalator Grażyna 5.1",
        "select_lang": "Wybierz język",
        "select_disk": "Wybierz dysk instalacji",
        "install": "Instaluj",
        "repair": "Napraw",
        "remove": "Usuń",
        "exit": "Wyjście",
        "progress": "Postęp instalacji",
        "checking_disk": "Sprawdzanie dysku...",
        "downloading_python": "Pobieranie Pythona...",
        "installing_python": "Instalacja Pythona...",
        "copying_python": "Kopiowanie PythonPortable...",
        "creating_structure": "Tworzenie struktury Grażyny...",
        "copying_files": "Kopiowanie plików...",
        "done": "Instalacja zakończona!",
        "error": "Błąd",
        "success": "Sukces",
        "disk_invalid": "Wybrany dysk nie jest NTFS, jest uszkodzony lub jest pendrive'em.",
        "confirm_remove": "Czy na pewno chcesz usunąć instalację?"
    },
    "EN": {
        "title": "Grażyna 5.1 Installer",
        "select_lang": "Select language",
        "select_disk": "Select installation drive",
        "install": "Install",
        "repair": "Repair",
        "remove": "Remove",
        "exit": "Exit",
        "progress": "Installation progress",
        "checking_disk": "Checking disk...",
        "downloading_python": "Downloading Python...",
        "installing_python": "Installing Python...",
        "copying_python": "Copying PythonPortable...",
        "creating_structure": "Creating Grażyna structure...",
        "copying_files": "Copying files...",
        "done": "Installation complete!",
        "error": "Error",
        "success": "Success",
        "disk_invalid": "Selected disk is not NTFS, damaged, or removable.",
        "confirm_remove": "Are you sure you want to remove the installation?"
    }
}

# =========================
# FUNKCJE SYSTEMOWE
# =========================

def get_drives():
    drives = []
    for part in psutil.disk_partitions(all=False):
        drives.append(part.device)
    return drives

def is_valid_drive(drive):
    try:
        part = psutil.disk_partitions(all=False)
        for p in part:
            if p.device == drive:
                if "removable" in p.opts.lower():
                    return False
                if p.fstype != "NTFS":
                    return False
                return True
    except:
        return False
    return False

def download_python(lang):
    import urllib.request
    urllib.request.urlretrieve(PYTHON_URL, PYTHON_INSTALLER)

def install_python(lang):
    subprocess.run([
        PYTHON_INSTALLER,
        "/quiet",
        "InstallAllUsers=1",
        "PrependPath=0",
        f"TargetDir={PYTHON_TARGET}",
        "Include_tcltk=1",
        "Include_pip=1"
    ], check=True)

def copy_python_portable(target):
    portable_path = os.path.join(target, "tools", "PythonPortable")
    if os.path.exists(portable_path):
        shutil.rmtree(portable_path)
    shutil.copytree(PYTHON_TARGET, portable_path)

def create_grazyna_structure(target):
    folders = [
        "data/logs",
        "modules",
        "listen",
        "update",
        "tools"
    ]
    for f in folders:
        os.makedirs(os.path.join(target, f), exist_ok=True)

def copy_grazyna_files(target):
    main_py = os.path.join(target, "main.py")
    launch_bat = os.path.join(target, "launch.bat")

    with open(main_py, "w", encoding="utf-8") as f:
        f.write("print('Grażyna 5.1 działa!')")

    with open(launch_bat, "w", encoding="utf-8") as f:
        f.write(
            "@echo off\n"
            "\"%~dp0tools\\PythonPortable\\python.exe\" \"%~dp0main.py\"\n"
            "pause\n"
        )

# =========================
# GUI INSTALATORA
# =========================

class InstallerGUI:
    def __init__(self):
        self.lang = "PL"
        self.text = LANGUAGES[self.lang]

        self.root = tk.Tk()
        self.root.title(self.text["title"])
        self.root.geometry("500x400")

        self.build_gui()

        self.root.mainloop()

    def build_gui(self):
        self.lang_label = ttk.Label(self.root, text=self.text["select_lang"])
        self.lang_label.pack(pady=10)

        self.lang_box = ttk.Combobox(self.root, values=["PL", "EN"])
        self.lang_box.current(0)
        self.lang_box.pack()
        self.lang_box.bind("<<ComboboxSelected>>", self.change_language)

        self.disk_label = ttk.Label(self.root, text=self.text["select_disk"])
        self.disk_label.pack(pady=10)

        self.disk_box = ttk.Combobox(self.root, values=get_drives())
        self.disk_box.pack()

        self.install_btn = ttk.Button(self.root, text=self.text["install"], command=self.install)
        self.install_btn.pack(pady=10)

        self.repair_btn = ttk.Button(self.root, text=self.text["repair"], command=self.repair)
        self.repair_btn.pack(pady=10)

        self.remove_btn = ttk.Button(self.root, text=self.text["remove"], command=self.remove)
        self.remove_btn.pack(pady=10)

        self.exit_btn = ttk.Button(self.root, text=self.text["exit"], command=self.root.destroy)
        self.exit_btn.pack(pady=10)

    def change_language(self, event=None):
        self.lang = self.lang_box.get()
        self.text = LANGUAGES[self.lang]
        self.root.title(self.text["title"])
        self.lang_label.config(text=self.text["select_lang"])
        self.disk_label.config(text=self.text["select_disk"])
        self.install_btn.config(text=self.text["install"])
        self.repair_btn.config(text=self.text["repair"])
        self.remove_btn.config(text=self.text["remove"])
        self.exit_btn.config(text=self.text["exit"])

    def install(self):
        drive = self.disk_box.get()
        if not is_valid_drive(drive):
            messagebox.showerror(self.text["error"], self.text["disk_invalid"])
            return

        target = os.path.join(drive, INSTALL_FOLDER_NAME)
        os.makedirs(target, exist_ok=True)

        self.run_installation_thread(target)

    def repair(self):
        messagebox.showinfo("Repair", "Tryb naprawy będzie dostępny w wersji 5.2.")

    def remove(self):
        drive = self.disk_box.get()
        target = os.path.join(drive, INSTALL_FOLDER_NAME)

        if not os.path.exists(target):
            messagebox.showerror(self.text["error"], "Brak instalacji.")
            return

        if messagebox.askyesno("Confirm", self.text["confirm_remove"]):
            shutil.rmtree(target)
            messagebox.showinfo(self.text["success"], "Usunięto instalację.")

    def run_installation_thread(self, target):
        self.progress_window = tk.Toplevel(self.root)
        self.progress_window.title(self.text["progress"])
        self.progress = ttk.Progressbar(self.progress_window, length=300, mode="determinate")
        self.progress.pack(pady=20)

        threading.Thread(target=self.installation_steps, args=(target,), daemon=True).start()

    def installation_steps(self, target):
        steps = [
            (self.text["downloading_python"], lambda: download_python(self.lang)),
            (self.text["installing_python"], lambda: install_python(self.lang)),
            (self.text["copying_python"], lambda: copy_python_portable(target)),
            (self.text["creating_structure"], lambda: create_grazyna_structure(target)),
            (self.text["copying_files"], lambda: copy_grazyna_files(target)),
        ]

        for i, (label, func) in enumerate(steps):
            self.progress_window.title(label)
            func()
            self.progress["value"] = (i + 1) * (100 / len(steps))
            time.sleep(0.5)

        messagebox.showinfo(self.text["success"], self.text["done"])
        self.progress_window.destroy()


# =========================
# START
# =========================

if __name__ == "__main__":
    InstallerGUI()
