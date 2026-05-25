import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import os
import sys
import threading
import subprocess
import json
import time
import shutil

import speech_recognition as sr
import pyttsx3

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# =========================
# KONFIGURACJA ŚCIEŻEK
# =========================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
LOG_DIR = os.path.join(DATA_DIR, "logs")
LISTEN_DIR = os.path.join(BASE_DIR, "listen")
MODULES_DIR = os.path.join(BASE_DIR, "modules")
UPDATE_DIR = os.path.join(BASE_DIR, "update")

SYSTEM_LOG = os.path.join(LOG_DIR, "system.log")

os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(LISTEN_DIR, exist_ok=True)
os.makedirs(MODULES_DIR, exist_ok=True)
os.makedirs(UPDATE_DIR, exist_ok=True)


# =========================
# LOGOWANIE
# =========================

def log(msg: str):
    ts = time.strftime("[%Y-%m-%d %H:%M:%S]")
    line = f"{ts} {msg}"
    print(line)
    try:
        with open(SYSTEM_LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


# =========================
# MODUŁY
# =========================

class ModuleManager:
    """
    Moduły w katalogu modules:
    - mod_nazwa.json (meta)
    - mod_nazwa.py   (kod)
    """
    def __init__(self, system):
        self.system = system
        self.modules = {}  # nazwa -> dict(meta, path)

    def scan_modules(self):
        self.modules.clear()
        if not os.path.isdir(MODULES_DIR):
            return

        for fname in os.listdir(MODULES_DIR):
            if not fname.lower().endswith(".json"):
                continue
            json_path = os.path.join(MODULES_DIR, fname)
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    meta = json.load(f)
                name = meta.get("name") or os.path.splitext(fname)[0]
                py_name = meta.get("entry", f"{name}.py")
                py_path = os.path.join(MODULES_DIR, py_name)
                self.modules[name] = {
                    "meta": meta,
                    "py_path": py_path
                }
                log(f"[MODULE] Załadowano meta modułu: {name}")
            except Exception as e:
                log(f"[MODULE] Błąd ładowania meta z {json_path}: {e}")

    def get_module_names(self):
        return list(self.modules.keys())

    def run_module(self, name: str):
        mod = self.modules.get(name)
        if not mod:
            log(f"[MODULE] Brak modułu: {name}")
            return

        py_path = mod["py_path"]
        if not os.path.isfile(py_path):
            log(f"[MODULE] Brak pliku modułu: {py_path}")
            return

        log(f"[MODULE] Uruchamianie modułu: {name} ({py_path})")
        try:
            subprocess.Popen([sys.executable, py_path], shell=True)
        except Exception as e:
            log(f"[MODULE] Błąd uruchamiania modułu {name}: {e}")


# =========================
# AUTO-UPDATE (LOKALNY)
# =========================

class AutoUpdater:
    """
    Prosty auto-update:
    - jeśli w update/main_new.py jest nowa wersja
    - można ją wgrać nadpisując main.py
    - restart ręczny
    """
    def __init__(self, system):
        self.system = system

    def check_update_available(self) -> bool:
        candidate = os.path.join(UPDATE_DIR, "main_new.py")
        return os.path.isfile(candidate)

    def apply_update(self):
        candidate = os.path.join(UPDATE_DIR, "main_new.py")
        if not os.path.isfile(candidate):
            messagebox.showinfo("Auto-update", "Brak pliku update/main_new.py")
            return

        backup = os.path.join(BASE_DIR, "main_backup.py")
        try:
            log("[UPDATE] Tworzę kopię main.py -> main_backup.py")
            shutil.copy2(os.path.join(BASE_DIR, "main.py"), backup)
            log("[UPDATE] Nadpisuję main.py nową wersją")
            shutil.copy2(candidate, os.path.join(BASE_DIR, "main.py"))
            messagebox.showinfo(
                "Auto-update",
                "Zastosowano nową wersję main.py.\nUruchom ponownie Grażynę."
            )
            log("[UPDATE] Zastosowano nową wersję main.py")
        except Exception as e:
            log(f"[UPDATE] Błąd aktualizacji: {e}")
            messagebox.showerror("Auto-update", f"Błąd aktualizacji: {e}")


# =========================
# WATCHDOG LISTEN/
# =========================

class ListenFileHandler(FileSystemEventHandler):
    def __init__(self, system):
        super().__init__()
        self.system = system

    def on_created(self, event):
        if event.is_directory:
            return
        file_path = event.src_path
        self.system.process_listen_file(file_path)


# =========================
# VOICE
# =========================

class VoiceTextSync:
    def __init__(self, system):
        self.system = system
        self.recognizer = sr.Recognizer()
        self.engine = pyttsx3.init()
        self.engine.setProperty('rate', 150)
        self.voice_enabled = True
        self.silent_mode = False

    def listen_loop(self):
        while self.voice_enabled:
            try:
                with sr.Microphone() as source:
                    log("[VOICE] Nasłuchiwanie...")
                    self.recognizer.adjust_for_ambient_noise(source)
                    audio = self.recognizer.listen(source, timeout=3)
                    command = self.recognizer.recognize_google(audio, language="pl-PL")
                    log(f"[VOICE] Użytkownik: {command}")
                    self.process_command(command)
            except sr.WaitTimeoutError:
                continue
            except Exception as e:
                log(f"[VOICE] Błąd rozpoznawania mowy: {e}")
                time.sleep(1)

    def speak(self, text: str):
        log(f"[VOICE] System: {text}")
        if self.silent_mode:
            return
        try:
            self.engine.say(text)
            self.engine.runAndWait()
        except Exception as e:
            log(f"[VOICE] Błąd syntezy mowy: {e}")

    def process_command(self, command: str):
        cmd = command.lower()

        # tryb cichy / głośny
        if "tryb cichy" in cmd:
            self.silent_mode = True
            self.speak("Przechodzę w tryb cichy.")
            return
        if "tryb głośny" in cmd:
            self.silent_mode = False
            self.speak("Przechodzę w tryb głośny.")
            return

        # raport systemu
        if "raport systemu" in cmd:
            self.speak("System działa. Moduły załadowane. Interfejs graficzny aktywny.")
            return

        # pokaż moduły
        if "pokaż moduły" in cmd:
            names = self.system.module_manager.get_module_names()
            if not names:
                self.speak("Brak zarejestrowanych modułów.")
            else:
                self.speak("Dostępne moduły: " + ", ".join(names))
            return

        # przeładuj system (moduły)
        if "przeładuj system" in cmd or "przeładuj moduły" in cmd:
            self.system.module_manager.scan_modules()
            self.system.refresh_module_buttons()
            self.speak("Przeładowałam moduły.")
            return

        # tryb diagnostyczny
        if "tryb diagnostyczny" in cmd:
            self.speak("Uruchamiam tryb diagnostyczny.")
            self.system.run_diagnostics()
            return

        # klasyczne komendy
        if "czat" in cmd:
            self.speak("Otwieram czat.")
            self.system.root.after(0, self.system.open_chat)
        elif "gpt" in cmd:
            self.speak("Otwieram GPT.")
        elif "obraz" in cmd:
            self.speak("Otwieram analizę obrazu.")
        elif "analiza" in cmd:
            self.speak("Otwieram analizę danych.")
        elif "kod" in cmd:
            self.speak("Otwieram edytor kodu.")
        elif "generacja" in cmd:
            self.speak("Otwieram generację.")
        else:
            self.speak("Nieznana komenda. Proszę spróbować ponownie.")


# =========================
# CHAT
# =========================

class ChatInterface:
    def __init__(self, root, system):
        self.root = root
        self.system = system

        self.chat_display = scrolledtext.ScrolledText(root, width=60, height=20)
        self.chat_display.pack(padx=10, pady=10)

        self.input_field = tk.Entry(root, width=60)
        self.input_field.pack(padx=10, pady=5)
        self.input_field.bind("<Return>", self.send_message)

        self.send_button = tk.Button(root, text="Wyślij", command=self.send_message)
        self.send_button.pack(pady=5)

        self.chat_display.insert(tk.END, "System gotowy. Wprowadź komendę.\n")

    def send_message(self, event=None):
        user_message = self.input_field.get()
        if not user_message.strip():
            return
        self.chat_display.insert(tk.END, f"Użytkownik: {user_message}\n")
        self.input_field.delete(0, tk.END)

        log(f"[CHAT] {user_message}")
        response = self.process_command(user_message)
        self.chat_display.insert(tk.END, f"System: {response}\n")

    def process_command(self, command: str) -> str:
        cmd = command.lower()
        if "czat" in cmd:
            return "Otwieranie czatu."
        elif "gpt" in cmd:
            return "Otwieranie GPT."
        elif "obraz" in cmd:
            return "Otwieranie analizy obrazu."
        elif "analiza" in cmd:
            return "Otwieranie analizy danych."
        elif "kod" in cmd:
            return "Otwieranie edytora kodu."
        elif "generacja" in cmd:
            return "Otwieranie generacji."
        elif "moduły" in cmd:
            names = self.system.module_manager.get_module_names()
            if not names:
                return "Brak zarejestrowanych modułów."
            return "Dostępne moduły: " + ", ".join(names)
        elif "update" in cmd:
            if self.system.auto_updater.check_update_available():
                self.system.auto_updater.apply_update()
                return "Zastosowano aktualizację, uruchom ponownie system."
            else:
                return "Brak dostępnej aktualizacji."
        else:
            return "Nieznana komenda. Proszę spróbować ponownie."


# =========================
# GŁÓWNY SYSTEM
# =========================

class GrazynaSystem:
    def __init__(self, root):
        self.root = root
        self.root.title("Grażyna 5.1 – System Taktyczny AI")

        self.module_manager = ModuleManager(self)
        self.auto_updater = AutoUpdater(self)

        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill=tk.BOTH, expand=True)

        self.main_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.main_frame, text="Panel główny")

        self.status_frame = ttk.Frame(root)
        self.status_frame.pack(fill=tk.X, side=tk.BOTTOM)

        self.module_buttons_frame = ttk.Frame(self.main_frame)
        self.module_buttons_frame.pack(fill=tk.X, pady=5)

        self.setup_tiles()
        self.setup_dashboard()
        self.setup_status_bar()

        self.voice_sync = VoiceTextSync(self)
        self.start_voice_listener()

        self.setup_listen_watchdog()

        self.module_manager.scan_modules()
        self.refresh_module_buttons()

        log("[SYSTEM] Grażyna 5.1 uruchomiona.")

    # --- GUI ---

    def setup_tiles(self):
        functions = [
            ("Czat", self.open_chat),
            ("GPT", self.open_gpt),
            ("Obraz", self.open_image),
            ("Analiza", self.open_analysis),
            ("Kod", self.open_code),
            ("Generacja", self.open_generation),
            ("Moduły", self.show_modules_info),
            ("Update", self.run_update),
        ]

        for name, command in functions:
            tile = ttk.Button(
                self.main_frame,
                text=name,
                command=command,
                width=15
            )
            tile.pack(padx=5, pady=5, side=tk.LEFT)

    def setup_dashboard(self):
        self.speed_label = ttk.Label(self.main_frame, text="Prędkość: 0 MB/s")
        self.speed_label.pack(pady=2)

        self.load_label = ttk.Label(self.main_frame, text="Obciążenie: 0%")
        self.load_label.pack(pady=2)

    def setup_status_bar(self):
        self.status_voice = ttk.Label(self.status_frame, text="VOICE: ON")
        self.status_voice.pack(side=tk.LEFT, padx=5)

        self.status_watchdog = ttk.Label(self.status_frame, text="WATCHDOG: ON")
        self.status_watchdog.pack(side=tk.LEFT, padx=5)

        self.status_modules = ttk.Label(self.status_frame, text="MODULES: 0")
        self.status_modules.pack(side=tk.LEFT, padx=5)

    def refresh_module_buttons(self):
        for w in self.module_buttons_frame.winfo_children():
            w.destroy()

        names = self.module_manager.get_module_names()
        for name in names:
            btn = ttk.Button(
                self.module_buttons_frame,
                text=f"MOD: {name}",
                command=lambda n=name: self.module_manager.run_module(n),
                width=20
            )
            btn.pack(side=tk.LEFT, padx=3, pady=3)

        self.status_modules.config(text=f"MODULES: {len(names)}")

    # --- LISTEN / WATCHDOG ---

    def setup_listen_watchdog(self):
        handler = ListenFileHandler(self)
        self.observer = Observer()
        self.observer.schedule(handler, LISTEN_DIR, recursive=False)
        self.observer.start()
        log("[WATCHDOG] Nasłuch folderu listen/ uruchomiony.")

    def process_listen_file(self, file_path: str):
        log(f"[LISTEN] Wykryto nowy plik: {file_path}")
        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
        except Exception as e:
            log(f"[LISTEN] Błąd odczytu pliku {file_path}: {e}")
            return

        log(f"[LISTEN] Zawartość: {content[:200]}")

        if file_path.endswith(".py"):
            self._add_dynamic_python_button(file_path)
        elif file_path.endswith(".ps1"):
            self._add_dynamic_powershell_button(file_path)
        elif file_path.endswith(".json"):
            self._process_json_file(file_path, content)

    def _add_dynamic_python_button(self, file_path: str):
        name = os.path.basename(file_path).split('.')[0]
        log(f"[LISTEN] Dodaję przycisk dla skryptu Python: {name}")

        def run_script():
            log(f"[LISTEN] Uruchamianie Pythona: {file_path}")
            subprocess.Popen([sys.executable, file_path], shell=True)

        btn = ttk.Button(
            self.main_frame,
            text=f"PY: {name}",
            command=run_script,
            width=15
        )
        btn.pack(padx=5, pady=5, side=tk.LEFT)

    def _add_dynamic_powershell_button(self, file_path: str):
        name = os.path.basename(file_path).split('.')[0]
        log(f"[LISTEN] Dodaję przycisk dla skryptu PowerShell: {name}")

        def run_script():
            log(f"[LISTEN] Uruchamianie PowerShell: {file_path}")
            subprocess.Popen(
                ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", file_path],
                shell=True
            )

        btn = ttk.Button(
            self.main_frame,
            text=f"PS: {name}",
            command=run_script,
            width=15
        )
        btn.pack(padx=5, pady=5, side=tk.LEFT)

    def _process_json_file(self, file_path: str, content: str):
        try:
            data = json.loads(content)
            log(f"[LISTEN] JSON dane: {data}")
        except json.JSONDecodeError as e:
            log(f"[LISTEN] Błąd JSON w {file_path}: {e}")

    # --- VOICE ---

    def start_voice_listener(self):
        t = threading.Thread(target=self.voice_sync.listen_loop, daemon=True)
        t.start()
        log("[VOICE] Wątek nasłuchu głosowego uruchomiony.")

    # --- DIAGNOSTYKA ---

    def run_diagnostics(self):
        log("[DIAG] Start diagnostyki.")
        issues = []

        for path, desc in [
            (DATA_DIR, "DATA_DIR"),
            (LOG_DIR, "LOG_DIR"),
            (LISTEN_DIR, "LISTEN_DIR"),
            (MODULES_DIR, "MODULES_DIR"),
        ]:
            if not os.path.isdir(path):
                issues.append(f"Brak katalogu: {desc} -> {path}")

        if issues:
            for i in issues:
                log(f"[DIAG] {i}")
            messagebox.showwarning("Diagnostyka", "\n".join(issues))
        else:
            log("[DIAG] Brak problemów strukturalnych.")
            messagebox.showinfo("Diagnostyka", "Struktura katalogów OK.")

    # --- AKCJE GUI ---

    def open_chat(self):
        win = tk.Toplevel(self.root)
        win.title("Czat z Systemem")
        ChatInterface(win, self)

    def open_gpt(self):
        log("[GUI] Otwieranie GPT...")

    def open_image(self):
        log("[GUI] Otwieranie analizy obrazu...")

    def open_analysis(self):
        log("[GUI] Otwieranie analizy danych...")

    def open_code(self):
        log("[GUI] Otwieranie edytora kodu...")

    def open_generation(self):
        log("[GUI] Otwieranie generacji...")

    def show_modules_info(self):
        names = self.module_manager.get_module_names()
        if not names:
            messagebox.showinfo("Moduły", "Brak zarejestrowanych modułów.")
        else:
            messagebox.showinfo("Moduły", "Dostępne moduły:\n" + "\n".join(names))

    def run_update(self):
        if self.auto_updater.check_update_available():
            self.auto_updater.apply_update()
        else:
            messagebox.showinfo("Auto-update", "Brak dostępnej aktualizacji.")


# =========================
# ENTRYPOINT
# =========================

if __name__ == "__main__":
    log("=== START GRAŻYNA 5.1 ===")
    root = tk.Tk()
    app = GrazynaSystem(root)
    root.mainloop()
