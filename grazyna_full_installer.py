"""
GRAZYNA MAX PRO LIVE NEON REAL MAX - Pełny Instalator Automatyczny
- Tworzy strukturę katalogów
- Kopiuje i uzupełnia brakujące pliki
- Instaluje zależności
- Generuje plik GRAZYNA_MAIN_LAUNCHER.py
- Uruchamia system
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path

class GrazynaInstaller:
    def __init__(self):
        # Główny katalog docelowy
        self.root_dir = Path.home() / "Grazyna"

        # Katalog źródłowy (gdzie znajdują się pliki)
        self.source_dir = Path.cwd()

        # Lista plików do skopiowania
        self.files_to_copy = [
            ("core/__init__.py", "core/__init__.py"),
            ("core/state.py", "core/state.py"),
            ("core/logger.py", "core/logger.py"),
            ("ui/__init__.py", "ui/__init__.py"),
            ("ui/panel_live/__init__.py", "ui/panel_live/__init__.py"),
            ("ui/panel_live/panel_live_neon_real_max.py", "ui/panel_live/panel_live_neon_real_max.py"),
            ("modules/__init__.py", "modules/__init__.py"),
            ("modules/tp_max.py", "modules/tp_max.py"),
            ("modules/ecu_diagnostic.py", "modules/ecu_diagnostic.py"),
            ("modules/flash_module.py", "modules/flash_module.py"),
            ("modules/tuning_module.py", "modules/tuning_module.py"),
        ]

        # Pliki do wygenerowania
        self.files_to_generate = {
            "GRAZYNA_MAIN_LAUNCHER.py": self._generate_main_launcher,
            "requirements.txt": self._generate_requirements,
            "launchers/start_grazyna.bat": self._generate_start_script,
            "launchers/start_grazyna.sh": self._generate_start_script_linux,
        }

    def _generate_main_launcher(self):
        """Generuje główny plik GRAZYNA_MAIN_LAUNCHER.py"""
        return '''import os
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
        os.system("cls" if os.name == "nt" else "clear")
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
        if choice == "1":
            self.start_module(run_tp_max)
        elif choice == "2":
            self.start_module(run_ecu_diagnostic)
        elif choice == "3":
            file_path = input("Podaj ścieżkę do pliku flash (lub naciśnij Enter): ").strip()
            self.start_module(run_flash_module, file_path if file_path else None)
        elif choice == "4":
            self.start_module(run_tuning_module)
        elif choice == "5":
            if self.panel:
                self.panel.stop()
            self.panel = GrazynaNeonRealMax()
            panel_thread = threading.Thread(target=self.panel.run, daemon=True)
            panel_thread.start()
            panel_thread.join()
        elif choice == "6":
            self.show_settings()
        elif choice == "7":
            self.show_logs()
        elif choice == "8":
            self.running = False
            log("INFO", "👋 Zamykanie systemu GRAŻYNA")
            if self.panel:
                self.panel.stop()
            sys.exit(0)
        else:
            log("WARNING", "Niewłaściwy wybór. Spróbuj ponownie.")

    def show_settings(self):
        """Wyświetla ustawienia systemu"""
        os.system("cls" if os.name == "nt" else "clear")
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
        if choice == "1":
            from core.state import MAX_MODE, enable_max_mode, disable_max_mode
            if MAX_MODE:
                disable_max_mode()
                log("INFO", "Tryb MAX MODE wyłączony")
            else:
                enable_max_mode()
                log("INFO", "Tryb MAX MODE włączony")
        elif choice == "2":
            self.show_connection_settings()
        elif choice == "3":
            self.show_log_settings()
        elif choice == "4":
            return
        else:
            log("WARNING", "Niewłaściwy wybór")

    def show_connection_settings(self):
        """Wyświetla ustawienia połączeń"""
        os.system("cls" if os.name == "nt" else "clear")
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
        if choice == "1":
            self.scan_usb_devices()
        elif choice == "2":
            self.scan_com_ports()
        elif choice == "3":
            self.test_connection()
        elif choice == "4":
            return
        else:
            log("WARNING", "Niewłaściwy wybór")

    def scan_usb_devices(self):
        """Skanuje urządzenia USB"""
        from ui.panel_live.panel_live_neon_real_max import GrazynaNeonRealMax
        temp_panel = GrazynaNeonRealMax()
        usb_devices = temp_panel.scan_usb()

        os.system("cls" if os.name == "nt" else "clear")
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

        os.system("cls" if os.name == "nt" else "clear")
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
        os.system("cls" if os.name == "nt" else "clear")
        print("""
📜 ZARZĄDZANIE LOGRAMI
===========================================
 [1] 🗑️  Wyczyść logi
 [2] 📤 Eksportuj logi do pliku
 [3] 🔙 Powrót
===========================================
        """)

        choice = input("Wybierz opcję (1-3): ").strip()
        if choice == "1":
            clear_logs()
            log("INFO", "Logi wyczyszczone")
        elif choice == "2":
            self.export_logs()
        elif choice == "3":
            return
        else:
            log("WARNING", "Niewłaściwy wybór")

    def export_logs(self):
        """Eksportuje logi do pliku"""
        try:
            from datetime import datetime
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            export_file = f"grazyna_logs_{timestamp}.txt"
            shutil.copy2("grazyna_system.log", export_file)
            log("INFO", f"Logi wyeksportowane do: {export_file}")
        except Exception as e:
            log("ERROR", f"Błąd eksportu logów: {e}")

    def show_logs(self):
        """Wyświetla logi systemowe"""
        os.system("cls" if os.name == "nt" else "clear")
        print("\n📜 LOGI SYSTEMOWE:")
        print("=" * 50)

        try:
            with open("grazyna_system.log", "r", encoding="utf-8") as f:
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
            t_panel = threading.Thread(target=self.start_panel, daemon=True)
            t_panel.start()

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
    from datetime import datetime
    launcher = GrazynaMainLauncher()
    launcher.run()
'''

    def _generate_requirements(self):
        """Generuje plik requirements.txt"""
        return '''rich>=13.0.0
pyusb>=1.2.1
pyserial>=3.5
'''

    def _generate_start_script(self):
        """Generuje skrypt startowy dla Windows"""
        return '''@echo off
cd %~dp0
python GRAZYNA_MAIN_LAUNCHER.py
pause
'''

    def _generate_start_script_linux(self):
        """Generuje skrypt startowy dla Linux/macOS"""
        return '''#!/bin/bash
cd "$(dirname "$0")"
python3 GRAZYNA_MAIN_LAUNCHER.py
read -p "Naciśnij Enter, aby kontynuować..."
'''

    def _create_directory_structure(self):
        """Tworzy strukturę katalogów"""
        print("📁 Tworzenie struktury katalogów...")

        directories = [
            "core",
            "ui/panel_live",
            "modules",
            "launchers"
        ]

        for dir_path in directories:
            (self.root_dir / dir_path).mkdir(parents=True, exist_ok=True)
            print(f"   ✅ Utworzono: {dir_path}")

    def _copy_files(self):
        """Kopiuje pliki z katalogu źródłowego"""
        print("\n📂 Kopiowanie plików...")

        for src_path, dest_path in self.files_to_copy:
            src_full = self.source_dir / src_path
            dest_full = self.root_dir / dest_path

            if src_full.exists():
                dest_full.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_full, dest_full)
                print(f"   ✅ Skopiowano: {src_path}")
            else:
                print(f"   ⚠️  Plik nie istnieje: {src_path}")

    def _generate_files(self):
        """Generuje brakujące pliki"""
        print("\n📝 Generowanie plików...")

        for filename, generator in self.files_to_generate.items():
            content = generator()
            filepath = self.root_dir / filename
            filepath.parent.mkdir(parents=True, exist_ok=True)

            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)

            print(f"   ✅ Wygenerowano: {filename}")

    def _install_dependencies(self):
        """Instaluje zależności Python"""
        print("\n📦 Instalacja zależności...")

        try:
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "-r", str(self.root_dir / "requirements.txt")],
                check=True,
                capture_output=True,
                text=True
            )
            print("   ✅ Zależności zainstalowane pomyślnie")
        except subprocess.CalledProcessError as e:
            print(f"   ⚠️  Błąd instalacji zależności: {e}")
            print("   💡 Spróbuj ręcznie: pip install rich pyusb pyserial")

    def run(self):
        """Uruchamia pełny proces instalacji"""
        print("🚀 GRAŻYNA MAX PRO LIVE NEON REAL MAX - INSTALATOR")
        print("=" * 60)

        # 1. Utwórz strukturę katalogów
        self._create_directory_structure()

        # 2. Kopiuj pliki
        self._copy_files()

        # 3. Wygeneruj brakujące pliki
        self._generate_files()

        # 4. Zainstaluj zależności
        self._install_dependencies()

        # 5. Podsumowanie
        print("\n" + "=" * 60)
        print("🎉 INSTALACJA ZAKOŃCZONA!")
        print("=" * 60)
        print(f"📂 System zainstalowany w: {self.root_dir}")
        print("\n🚀 Uruchom system:")
        print(f"   cd {self.root_dir}")
        if sys.platform == "win32":
            print("   .\\launchers\\start_grazyna.bat")
        else:
            print("   ./launchers/start_grazyna.sh")

        # Opcjonalnie: Uruchom system
        run_now = input("\nCzy uruchomić system teraz? (T/N): ").strip().lower()
        if run_now == "t":
            os.chdir(self.root_dir)
            if sys.platform == "win32":
                os.system(".\\launchers\\start_grazyna.bat")
            else:
                os.system("./launchers/start_grazyna.sh")

if __name__ == "__main__":
    installer = GrazynaInstaller()
    installer.run()