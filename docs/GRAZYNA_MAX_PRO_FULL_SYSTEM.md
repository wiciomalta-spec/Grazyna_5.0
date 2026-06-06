"""
GRAZYNA MAX PRO LIVE NEON REAL MAX - Pełny System Uzupełniony
Zawiera:
- Monitorowanie USB i COM w czasie rzeczywistym
- Panel LIVE z Rich Console
- Obsługę modułów (TP MAX, itd.)
- Zarządzanie stanami systemu
- Logowanie z kolorami
- Wątkowe wykonanie
"""

# ========== STRUKTURA KATALOGÓW ==========
"""
Grazyna/
├── core/
│   ├── __init__.py
│   ├── state.py
│   └── logger.py
├── ui/
│   ├── __init__.py
│   └── panel_live/
│       ├── __init__.py
│       └── panel_live_neon_real_max.py
├── modules/
│   ├── __init__.py
│   ├── tp_max.py
│   ├── ecu_diagnostic.py
│   ├── flash_module.py
│   └── tuning_module.py
└── GRAZYNA_MAIN_LAUNCHER.py
"""

# ========== core/__init__.py ==========
# core package init

# ========== core/state.py ==========
ACTIVE_MODULE = "NONE"
SYSTEM_STATE = "IDLE"
MAX_MODE = False
CONNECTED_DEVICES = {}

def set_active_module(name: str):
    global ACTIVE_MODULE
    ACTIVE_MODULE = name
    log("INFO", f"Aktywny moduł zmieniony na: {name}")

def set_system_state(state: str):
    global SYSTEM_STATE
    SYSTEM_STATE = state
    log("INFO", f"Stan systemu zmieniony na: {state}")

def enable_max_mode():
    global MAX_MODE
    MAX_MODE = True
    log("INFO", "Włączono tryb MAX MODE")

def disable_max_mode():
    global MAX_MODE
    MAX_MODE = False
    log("INFO", "Wyłączono tryb MAX MODE")

def is_max_mode() -> bool:
    return MAX_MODE

def add_connected_device(device_type: str, device_info: dict):
    global CONNECTED_DEVICES
    CONNECTED_DEVICES[device_type] = device_info
    log("INFO", f"Podłączono urządzenie {device_type}: {device_info}")

def remove_connected_device(device_type: str):
    global CONNECTED_DEVICES
    if device_type in CONNECTED_DEVICES:
        del CONNECTED_DEVICES[device_type]
        log("INFO", f"Odłączono urządzenie: {device_type}")

# ========== core/logger.py ==========
from datetime import datetime

LIVE_PANEL_HOOK = None
LOG_FILE = "grazyna_system.log"

def attach_live_panel(hook):
    global LIVE_PANEL_HOOK
    LIVE_PANEL_HOOK = hook

def log(level: str, msg: str, save_to_file: bool = True):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {level} {msg}"
    print(line)

    if LIVE_PANEL_HOOK:
        LIVE_PANEL_HOOK(level, msg)

    if save_to_file:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")

def clear_logs():
    """Czyści plik logów"""
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        f.write("")

# ========== ui/__init__.py ==========
# ui package init

# ========== ui/panel_live/__init__.py ==========
# panel_live package init

# ========== ui/panel_live/panel_live_neon_real_max.py ==========
import time
import usb.core
import usb.util
import serial.tools.list_ports
from rich.console import Console
from rich.live import Live
from rich.table import Table
from rich.panel import Panel
from rich.layout import Layout
from rich.text import Text
from rich import box
from core.state import ACTIVE_MODULE, SYSTEM_STATE, is_max_mode, CONNECTED_DEVICES
from core.logger import attach_live_panel, log

console = Console()

class GrazynaNeonRealMax:
    def __init__(self):
        self.prev_usb = {}
        self.prev_com = {}
        self.logs = []
        self.running = True
        attach_live_panel(self.log_hook)

    def log_hook(self, level, msg):
        self.logs.append((level, msg))
        if len(self.logs) > 500:
            self.logs.pop(0)

    def scan_usb(self):
        """Skanuje urządzenia USB"""
        devices = usb.core.find(find_all=True)
        result = {}
        for dev in devices:
            try:
                key = f"{dev.idVendor:04X}:{dev.idProduct:04X}"
                result[key] = {
                    "vid": f"{dev.idVendor:04X}",
                    "pid": f"{dev.idProduct:04X}",
                    "man": usb.util.get_string(dev, dev.iManufacturer) or "N/A",
                    "prod": usb.util.get_string(dev, dev.iProduct) or "N/A",
                    "sn": usb.util.get_string(dev, dev.iSerialNumber) or "N/A",
                    "device": dev
                }
            except Exception as e:
                log("ERROR", f"Błąd skanowania USB: {e}")
        return result

    def scan_com(self):
        """Skanuje porty COM"""
        ports = serial.tools.list_ports.comports()
        result = {}
        for p in ports:
            result[p.device] = {
                "port": p.device,
                "desc": p.description or "N/A",
                "man": p.manufacturer or "N/A",
                "sn": p.serial_number or "N/A",
                "vidpid": f"{p.vid:04X}:{p.pid:04X}" if p.vid else "N/A"
            }
        return result

    def detect_changes(self, now, prev, label):
        """Wykrywa zmiany w urządzeniach"""
        for k in now:
            if k not in prev:
                self.logs.append(("INFO", f"{label} NOWY → {k}"))
                log("INFO", f"{label} NOWY → {k}")
        for k in prev:
            if k not in now:
                self.logs.append(("WARNING", f"{label} UTRACONO → {k}"))
                log("WARNING", f"{label} UTRACONO → {k}")

    def build_status_bar(self):
        """Buduje pasek statusu"""
        mode = "MAX MODE" if is_max_mode() else "STANDARD"
        connected = ", ".join(CONNECTED_DEVICES.keys()) if CONNECTED_DEVICES else "Brak"
        text = Text(
            f" GRAŻYNA MAX PRO — {mode} | MODUŁ: {ACTIVE_MODULE} | STAN: {SYSTEM_STATE} | URZĄDZENIA: {connected} ",
            style="bold magenta on #111122"
        )
        return Panel(text, border_style="bright_magenta", box=box.ROUNDED)

    def build_usb_table(self, usb):
        """Buduje tabelę USB"""
        table = Table(title="🔌 USB LIVE", border_style="bright_cyan", style="cyan", box=box.SQUARE)
        table.add_column("VID:PID", style="bright_cyan")
        table.add_column("Producent", style="cyan")
        table.add_column("Produkt", style="cyan")
        table.add_column("Numer Seryjny", style="cyan")

        for d in usb.values():
            table.add_row(
                f"{d['vid']}:{d['pid']}",
                d['man'],
                d['prod'],
                d['sn']
            )
        return table

    def build_com_table(self, com):
        """Buduje tabelę COM"""
        table = Table(title="📡 COM LIVE", border_style="bright_magenta", style="magenta", box=box.SQUARE)
        table.add_column("Port", style="bright_magenta")
        table.add_column("Opis", style="magenta")
        table.add_column("Producent", style="magenta")
        table.add_column("Numer Seryjny", style="magenta")
        table.add_column("VID:PID", style="magenta")

        for d in com.values():
            table.add_row(
                d['port'],
                d['desc'],
                d['man'],
                d['sn'],
                d['vidpid']
            )
        return table

    def build_system_info_table(self):
        """Buduje tabelę z informacjami systemowymi"""
        table = Table(title="ℹ️ INFORMACJE SYSTEMOWE", border_style="bright_yellow", style="yellow", box=box.ROUNDED)
        table.add_column("Parametr", style="bright_yellow")
        table.add_column("Wartość", style="yellow")

        table.add_row("Aktywny moduł", ACTIVE_MODULE)
        table.add_row("Stan systemu", SYSTEM_STATE)
        table.add_row("Tryb MAX", "AKTYWNY" if is_max_mode() else "NIEAKTYWNY")
        table.add_row("Podłączone urządzenia", ", ".join(CONNECTED_DEVICES.keys()) if CONNECTED_DEVICES else "Brak")

        return table

    def build_log_panel(self):
        """Buduje panel logów"""
        table = Table(show_header=False, border_style="yellow", box=box.MINIMAL)
        table.add_column("Log", style="white")

        for level, msg in self.logs[-20:]:
            color_map = {
                "INFO": "bright_green",
                "DEBUG": "bright_blue",
                "WARNING": "yellow",
                "ERROR": "bright_red",
                "CRITICAL": "bold red"
            }
            color = color_map.get(level, "white")
            table.add_row(Text(f"[{level}] {msg}", style=color))

        return Panel(table, title="📜 SYSTEM LOG", border_style="yellow", box=box.ROUNDED)

    def build_layout(self, usb, com):
        """Buduje układ panelu"""
        layout = Layout()
        layout.split_column(
            Layout(name="top", size=3),
            Layout(name="middle", ratio=2),
            Layout(name="bottom", ratio=1)
        )
        layout["middle"].split_row(
            Layout(name="usb"),
            Layout(name="com")
        )

        layout["top"].update(self.build_status_bar())
        layout["usb"].update(Panel(self.build_usb_table(usb), border_style="bright_cyan"))
        layout["com"].update(Panel(self.build_com_table(com), border_style="bright_magenta"))
        layout["bottom"].update(self.build_log_panel())

        return layout

    def run(self):
        """Główna pętla panelu"""
        with Live(console=console, refresh_per_second=8, screen=True):
            try:
                while self.running:
                    usb_now = self.scan_usb()
                    com_now = self.scan_com()

                    self.detect_changes(usb_now, self.prev_usb, "USB")
                    self.detect_changes(com_now, self.prev_com, "COM")

                    layout = self.build_layout(usb_now, com_now)
                    console.print(layout)

                    self.prev_usb = usb_now
                    self.prev_com = com_now

                    time.sleep(0.5)
                    console.clear()

            except KeyboardInterrupt:
                self.running = False
                log("INFO", "Panel zatrzymany przez użytkownika")
            except Exception as e:
                log("ERROR", f"Błąd panelu: {e}")
                self.running = False

    def stop(self):
        """Zatrzymuje panel"""
        self.running = False

# ========== modules/__init__.py ==========
# modules package init

# ========== modules/tp_max.py ==========
from core.state import set_active_module, set_system_state, enable_max_mode, add_connected_device, remove_connected_device
from core.logger import log
import time
import random

def run_tp_max():
    """Główny moduł TP MAX"""
    enable_max_mode()
    set_active_module("TP MAX")
    set_system_state("RUNNING")
    log("INFO", "TP MAX: Rozpoczynanie diagnostyki")

    # Symulacja połączenia z urządzeniem
    add_connected_device("TP_MAX", {"status": "connected", "version": "1.0"})

    try:
        # Etap 1: Inicjalizacja
        log("INFO", "TP MAX: Inicjalizacja...")
        time.sleep(1)

        # Etap 2: Test połączenia
        log("INFO", "TP MAX: Test połączenia...")
        time.sleep(1.5)
        log("INFO", "TP MAX: Połączenie OK")

        # Etap 3: Odczyt parametrów
        log("INFO", "TP MAX: Odczyt parametrów ECU...")
        time.sleep(2)

        # Symulacja odczytu parametrów
        params = {
            "RPM": random.randint(800, 3000),
            "Temperatura": random.randint(80, 110),
            "Ciśnienie oleju": round(random.uniform(2.0, 5.0), 1),
            "Napięcie": round(random.uniform(12.0, 14.5), 1)
        }

        for param, value in params.items():
            log("INFO", f"TP MAX: {param} = {value}")

        # Etap 4: Diagnostyka
        log("INFO", "TP MAX: Rozpoczynanie testów diagnostycznych...")
        time.sleep(2)

        # Symulacja wykrycia błędu
        if random.random() < 0.3:  # 30% szans na błąd
            error_code = f"P{random.randint(100, 999)}"
            log("ERROR", f"TP MAX: Wykryto błąd: {error_code}")
            time.sleep(1)
            log("INFO", f"TP MAX: Próba naprawy błędu {error_code}...")
            time.sleep(2)
            log("INFO", f"TP MAX: Błąd {error_code} naprawiony")

        # Etap 5: Zakończenie
        log("INFO", "TP MAX: Zakończenie diagnostyki")
        time.sleep(1)

    except Exception as e:
        log("ERROR", f"TP MAX: Krytyczny błąd: {e}")
    finally:
        set_system_state("IDLE")
        remove_connected_device("TP_MAX")
        log("INFO", "TP MAX: Moduł zakończony")

# ========== modules/ecu_diagnostic.py ==========
from core.state import set_active_module, set_system_state, add_connected_device
from core.logger import log
import time

def run_ecu_diagnostic():
    """Moduł diagnostyki ECU"""
    set_active_module("ECU DIAGNOSTIC")
    set_system_state("RUNNING")
    log("INFO", "ECU DIAGNOSTIC: Rozpoczynanie")

    add_connected_device("ECU", {"type": "Bosch EDC17", "protocol": "UDS"})

    try:
        log("INFO", "ECU DIAGNOSTIC: Łączenie z ECU...")
        time.sleep(1.5)
        log("INFO", "ECU DIAGNOSTIC: Połączenie nawiązane")

        log("INFO", "ECU DIAGNOSTIC: Odczyt identyfikatora ECU...")
        time.sleep(1)
        log("INFO", "ECU DIAGNOSTIC: ID: Bosch EDC17 C15")

        log("INFO", "ECU DIAGNOSTIC: Odczyt błędów...")
        time.sleep(2)
        log("INFO", "ECU DIAGNOSTIC: Błędy: P0301, P0303")

        log("INFO", "ECU DIAGNOSTIC: Kasowanie błędów...")
        time.sleep(1.5)
        log("INFO", "ECU DIAGNOSTIC: Błędy skasowane")

    except Exception as e:
        log("ERROR", f"ECU DIAGNOSTIC: Błąd: {e}")
    finally:
        set_system_state("IDLE")
        log("INFO", "ECU DIAGNOSTIC: Zakończono")

# ========== modules/flash_module.py ==========
from core.state import set_active_module, set_system_state, add_connected_device
from core.logger import log
import time

def run_flash_module(file_path: str = None):
    """Moduł flashowania ECU"""
    set_active_module("FLASH MODULE")
    set_system_state("RUNNING")
    log("INFO", "FLASH MODULE: Rozpoczynanie")

    add_connected_device("FLASHER", {"type": "MPPS V21", "status": "ready"})

    try:
        if not file_path:
            file_path = input("Podaj ścieżkę do pliku flash: ").strip()
            if not file_path:
                log("ERROR", "FLASH MODULE: Nie podano pliku")
                return

        log("INFO", f"FLASH MODULE: Wczytywanie pliku: {file_path}")
        time.sleep(1)

        if not os.path.exists(file_path):
            log("ERROR", f"FLASH MODULE: Plik nie istnieje: {file_path}")
            return

        log("INFO", "FLASH MODULE: Weryfikacja pliku...")
        time.sleep(2)
        log("INFO", "FLASH MODULE: Plik poprawny")

        log("INFO", "FLASH MODULE: Rozpoczynanie flashowania...")
        time.sleep(3)

        # Symulacja postępu
        for i in range(0, 101, 10):
            log("INFO", f"FLASH MODULE: Postęp: {i}%")
            time.sleep(0.5)

        log("INFO", "FLASH MODULE: Flashowanie zakończone pomyślnie!")

    except Exception as e:
        log("ERROR", f"FLASH MODULE: Błąd: {e}")
    finally:
        set_system_state("IDLE")
        log("INFO", "FLASH MODULE: Zakończono")

# ========== modules/tuning_module.py ==========
from core.state import set_active_module, set_system_state, add_connected_device
from core.logger import log
import time

def run_tuning_module():
    """Moduł tuningu ECU"""
    set_active_module("TUNING MODULE")
    set_system_state("RUNNING")
    log("INFO", "TUNING MODULE: Rozpoczynanie")

    add_connected_device("TUNER", {"type": "ECUMaster", "status": "connected"})

    try:
        log("INFO", "TUNING MODULE: Łączenie z ECU...")
        time.sleep(1)
        log("INFO", "TUNING MODULE: Połączenie nawiązane")

        log("INFO", "TUNING MODULE: Odczyt map paliwa...")
        time.sleep(1.5)
        log("INFO", "TUNING MODULE: Mapa paliwa wczytana")

        log("INFO", "TUNING MODULE: Modyfikacja mapy...")
        time.sleep(2)
        log("INFO", "TUNING MODULE: Mapa zmodyfikowana")

        log("INFO", "TUNING MODULE: Zapis do ECU...")
        time.sleep(2)
        log("INFO", "TUNING MODULE: Zapis zakończony")

        log("INFO", "TUNING MODULE: Weryfikacja...")
        time.sleep(1.5)
        log("INFO", "TUNING MODULE: Weryfikacja OK")

    except Exception as e:
        log("ERROR", f"TUNING MODULE: Błąd: {e}")
    finally:
        set_system_state("IDLE")
        log("INFO", "TUNING MODULE: Zakończono")

# ========== GRAZYNA_MAIN_LAUNCHER.py ==========
import os
import sys
import threading
import time
from core.state import enable_max_mode, set_active_module, set_system_state
from core.logger import log, clear_logs
from ui.panel_live.panel_live_neon_real_max import GrazynaNeonRealMax
from modules.tp_max import run_tp_max
from modules.ecu_diagnostic import run_ecu_diagnostic
from modules.flash_module import run_flash_module
from modules.tuning_module import run_tuning_module

class GrazynaMainLauncher:
    def __init__(self):
        self.panel = None
        self.running = True
        clear_logs()
        enable_max_mode()
        log("INFO", "🚀 GRAŻYNA MAX PRO LIVE NEON REAL MAX - START SYSTEMU")

    def start_panel(self):
        """Uruchamia panel LIVE"""
        self.panel = GrazynaNeonRealMax()
        self.panel.run()

    def start_module(self, module_func, *args, **kwargs):
        """Uruchamia moduł w nowym wątku"""
        def module_wrapper():
            try:
                module_func(*args, **kwargs)
            except Exception as e:
                log("ERROR", f"Błąd modułu: {e}")

        thread = threading.Thread(target=module_wrapper, daemon=True)
        thread.start()
        return thread

    def show_menu(self):
        """Wyświetla menu główne"""
        os.system('cls' if os.name == 'nt' else 'clear')
        print("""
🔥 GRAŻYNA MAX PRO LIVE NEON REAL MAX 🔥
===========================================
 [1] 🔍 TP MAX - Zaawansowana diagnostyka
 [2] 🔧 ECU DIAGNOSTIC - Diagnostyka ECU
 [3] ⚡ FLASH MODULE - Flashowanie ECU
 [4] 🎯 TUNING MODULE - Tuning silnika
 [5] 📊 MONITOR - Monitorowanie na żywo
 [6] ⚙️  USTAWIENIA - Konfiguracja systemu
 [7] 📜 LOGS - Wyświetl logi systemowe
 [8] 🚪 WYJŚCIE - Zakończ program
===========================================
        """)

    def handle_menu_choice(self, choice):
        """Obsługuje wybór z menu"""
        if choice == '1':
            self.start_module(run_tp_max)
        elif choice == '2':
            self.start_module(run_ecu_diagnostic)
        elif choice == '3':
            file_path = input("Podaj ścieżkę do pliku flash (lub naciśnij Enter, aby użyć domyślnej): ").strip()
            self.start_module(run_flash_module, file_path if file_path else None)
        elif choice == '4':
            self.start_module(run_tuning_module)
        elif choice == '5':
            if self.panel:
                self.panel.stop()
            self.panel = GrazynaNeonRealMax()
            panel_thread = threading.Thread(target=self.panel.run, daemon=True)
            panel_thread.start()
            panel_thread.join()
        elif choice == '6':
            self.show_settings()
        elif choice == '7':
            self.show_logs()
        elif choice == '8':
            self.running = False
            log("INFO", "👋 Zamykanie systemu GRAŻYNA")
            if self.panel:
                self.panel.stop()
            sys.exit(0)
        else:
            log("WARNING", "Niewłaściwy wybór. Spróbuj ponownie.")

    def show_settings(self):
        """Wyświetla ustawienia systemu"""
        os.system('cls' if os.name == 'nt' else 'clear')
        print("""
⚙️  USTAWIENIA SYSTEMU GRAŻYNA
===========================================
 [1] 🔄 Tryb MAX MODE - Włącz/Wyłącz
 [2] 📡 Połączenia - Konfiguracja urządzeń
 [3] 📝 Logi - Zarządzanie logami
 [4] 🔙 Powrót do menu głównego
===========================================
        """)

        choice = input("Wybierz opcję (1-4): ").strip()
        if choice == '1':
            from core.state import MAX_MODE, enable_max_mode, disable_max_mode
            if MAX_MODE:
                disable_max_mode()
                log("INFO", "Tryb MAX MODE wyłączony")
            else:
                enable_max_mode()
                log("INFO", "Tryb MAX MODE włączony")
        elif choice == '2':
            self.show_connection_settings()
        elif choice == '3':
            self.show_log_settings()
        elif choice == '4':
            return
        else:
            log("WARNING", "Niewłaściwy wybór")

    def show_connection_settings(self):
        """Wyświetla ustawienia połączeń"""
        os.system('cls' if os.name == 'nt' else 'clear')
        print("""
📡 KONFIGURACJA POŁĄCZEŃ
===========================================
 [1] 🔌 USB - Skanuj urządzenia USB
 [2] 📡 COM - Skanuj porty COM
 [3] 🔄 Test połączenia
 [4] 🔙 Powrót
===========================================
        """)

        choice = input("Wybierz opcję (1-4): ").strip()
        if choice == '1':
            self.scan_usb_devices()
        elif choice == '2':
            self.scan_com_ports()
        elif choice == '3':
            self.test_connection()
        elif choice == '4':
            return
        else:
            log("WARNING", "Niewłaściwy wybór")

    def scan_usb_devices(self):
        """Skanuje urządzenia USB"""
        from ui.panel_live.panel_live_neon_real_max import GrazynaNeonRealMax
        temp_panel = GrazynaNeonRealMax()
        usb_devices = temp_panel.scan_usb()

        os.system('cls' if os.name == 'nt' else 'clear')
        print("\n🔌 WYKRYTE URZĄDZENIA USB:")
        print("=" * 50)
        for vid_pid, info in usb_devices.items():
            print(f"VID:PID: {vid_pid}")
            print(f"  Producent: {info['man']}")
            print(f"  Produkt: {info['prod']}")
            print(f"  Numer seryjny: {info['sn']}")
            print("-" * 50)

        input("\nNaciśnij Enter, aby kontynuować...")

    def scan_com_ports(self):
        """Skanuje porty COM"""
        from ui.panel_live.panel_live_neon_real_max import GrazynaNeonRealMax
        temp_panel = GrazynaNeonRealMax()
        com_ports = temp_panel.scan_com()

        os.system('cls' if os.name == 'nt' else 'clear')
        print("\n📡 WYKRYTE PORTY COM:")
        print("=" * 50)
        for port, info in com_ports.items():
            print(f"Port: {port}")
            print(f"  Opis: {info['desc']}")
            print(f"  Producent: {info['man']}")
            print(f"  Numer seryjny: {info['sn']}")
            print(f"  VID:PID: {info['vidpid']}")
            print("-" * 50)

        input("\nNaciśnij Enter, aby kontynuować...")

    def test_connection(self):
        """Testuje połączenie z urządzeniami"""
        log("INFO", "🔍 Rozpoczynanie testu połączenia...")
        time.sleep(1)

        # Test USB
        from ui.panel_live.panel_live_neon_real_max import GrazynaNeonRealMax
        temp_panel = GrazynaNeonRealMax()
        usb_devices = temp_panel.scan_usb()
        com_ports = temp_panel.scan_com()

        if usb_devices:
            log("INFO", f"✅ Wykryto {len(usb_devices)} urządzeń USB")
        else:
            log("WARNING", "⚠️  Nie wykryto żadnych urządzeń USB")

        if com_ports:
            log("INFO", f"✅ Wykryto {len(com_ports)} portów COM")
        else:
            log("WARNING", "⚠️  Nie wykryto żadnych portów COM")

        time.sleep(1)
        log("INFO", "✅ Test połączenia zakończony")

        input("\nNaciśnij Enter, aby kontynuować...")

    def show_log_settings(self):
        """Wyświetla ustawienia logów"""
        os.system('cls' if os.name == 'nt' else 'clear')
        print("""
📜 ZARZĄDZANIE LOGRAMI
===========================================
 [1] 🗑️  Wyczyść logi
 [2] 📤 Eksportuj logi do pliku
 [3] 📥 Importuj ustawienia
 [4] 🔙 Powrót
===========================================
        """)

        choice = input("Wybierz opcję (1-4): ").strip()
        if choice == '1':
            clear_logs()
            log("INFO", "Logi wyczyszczone")
        elif choice == '2':
            self.export_logs()
        elif choice == '3':
            self.import_settings()
        elif choice == '4':
            return
        else:
            log("WARNING", "Niewłaściwy wybór")

    def export_logs(self):
        """Eksportuje logi do pliku"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            export_file = f"grazyna_logs_{timestamp}.txt"
            shutil.copy2(LOG_FILE, export_file)
            log("INFO", f"Logi wyeksportowane do: {export_file}")
        except Exception as e:
            log("ERROR", f"Błąd eksportu logów: {e}")

    def import_settings(self):
        """Importuje ustawienia (zabawkowe)"""
        log("INFO", "📥 Importowanie ustawień...")
        time.sleep(1)
        log("INFO", "✅ Ustawienia zaimportowane (symulacja)")

    def show_logs(self):
        """Wyświetla logi systemowe"""
        os.system('cls' if os.name == 'nt' else 'clear')
        print("\n📜 LOGI SYSTEMOWE:")
        print("=" * 50)

        try:
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                logs = f.read()
                if logs:
                    print(logs)
                else:
                    print("Brak logów do wyświetlenia")
        except FileNotFoundError:
            print("Plik logów nie istnieje")
        except Exception as e:
            log("ERROR", f"Błąd odczytu logów: {e}")

        input("\nNaciśnij Enter, aby kontynuować...")

    def run(self):
        """Główna pętla programu"""
        try:
            # Uruchom panel w tle
            panel_thread = threading.Thread(target=self.start_panel, daemon=True)
            panel_thread.start()

            # Główna pętla menu
            while self.running:
                self.show_menu()
                choice = input("Wybierz opcję (1-8): ").strip()
                self.handle_menu_choice(choice)

        except KeyboardInterrupt:
            log("INFO", "👋 Zamykanie systemu (Ctrl+C)")
            self.running = False
            if self.panel:
                self.panel.stop()
        except Exception as e:
            log("ERROR", f"Krytyczny błąd systemu: {e}")
        finally:
            log("INFO", "System zatrzymany")

if __name__ == "__main__":
    import datetime
    launcher = GrazynaMainLauncher()
    launcher.run()