# GRAZYNA MAX PRO LIVE NEON REAL MAX - Pełny Instalator dla PowerShell
# Wklej tę komendę w katalogu, w którym znajdują się Twoje pliki źródłowe

# 1. Utwórz główny katalog docelowy
$rootDir = "$env:USERPROFILE\Grazyna"
if (-not (Test-Path $rootDir)) {
    New-Item -ItemType Directory -Path $rootDir -Force | Out-Null
    Write-Host "📁 Utworzono katalog: $rootDir"
}

# 2. Utwórz strukturę katalogów
$directories = @(
    "core",
    "ui\panel_live",
    "modules",
    "launchers"
)

foreach ($dir in $directories) {
    $fullPath = Join-Path $rootDir $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "   ✅ Utworzono: $dir"
    }
}

# 3. Skopiuj istniejące pliki (jeśli są w bieżącym katalogu)
$filesToCopy = @(
    @{Source="core\__init__.py"; Dest="core\__init__.py"},
    @{Source="core\state.py"; Dest="core\state.py"},
    @{Source="core\logger.py"; Dest="core\logger.py"},
    @{Source="ui\__init__.py"; Dest="ui\__init__.py"},
    @{Source="ui\panel_live\__init__.py"; Dest="ui\panel_live\__init__.py"},
    @{Source="ui\panel_live\panel_live_neon_real_max.py"; Dest="ui\panel_live\panel_live_neon_real_max.py"},
    @{Source="modules\__init__.py"; Dest="modules\__init__.py"},
    @{Source="modules\tp_max.py"; Dest="modules\tp_max.py"},
    @{Source="modules\ecu_diagnostic.py"; Dest="modules\ecu_diagnostic.py"},
    @{Source="modules\flash_module.py"; Dest="modules\flash_module.py"},
    @{Source="modules\tuning_module.py"; Dest="modules\tuning_module.py"}
)

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path (Get-Location) $file.Source
    $destPath = Join-Path $rootDir $file.Dest

    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "   ✅ Skopiowano: $($file.Source)"
    } else {
        Write-Host "   ⚠️  Plik nie istnieje: $($file.Source)"
    }
}

# 4. Wygeneruj brakujące pliki

# 4.1. requirements.txt
$requirementsContent = @"
rich>=13.0.0
pyusb>=1.2.1
pyserial>=3.5
"@
$requirementsPath = Join-Path $rootDir "requirements.txt"
$requirementsContent | Out-File -FilePath $requirementsPath -Encoding utf8
Write-Host "   ✅ Wygenerowano: requirements.txt"

# 4.2. GRAZYNA_MAIN_LAUNCHER.py
$mainLauncherContent = @"
import os
import sys
import threading
import time
from datetime import datetime
from core.state import enable_max_mode, set_active_module, set_system_state, MAX_MODE, disable_max_mode
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
        self.panel = GrazynaNeonRealMax()
        self.panel.run()

    def start_module(self, module_func, *args, **kwargs):
        def module_wrapper():
            try:
                module_func(*args, **kwargs)
            except Exception as e:
                log("ERROR", f"Błąd modułu: {e}")

        thread = threading.Thread(target=module_wrapper, daemon=True)
        thread.start()
        return thread

    def show_menu(self):
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
        if choice == "1":
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
        os.system('cls' if os.name == 'nt' else 'clear')
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
        try:
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $exportFile = "grazyna_logs_$timestamp.txt"
            Copy-Item -Path "grazyna_system.log" -Destination $exportFile -Force
            log("INFO", f"Logi wyeksportowane do: {exportFile}")
        except Exception as e:
            log("ERROR", f"Błąd eksportu logów: {e}")

    def show_logs(self):
        os.system('cls' if os.name == 'nt' else 'clear')
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
    launcher = GrazynaMainLauncher()
    launcher.run()
"@
$mainLauncherPath = Join-Path $rootDir "GRAZYNA_MAIN_LAUNCHER.py"
$mainLauncherContent | Out-File -FilePath $mainLauncherPath -Encoding utf8
Write-Host "   ✅ Wygenerowano: GRAZYNA_MAIN_LAUNCHER.py"

# 4.3. start_grazyna.bat
$startScriptContent = @"
@echo off
cd %~dp0
python GRAZYNA_MAIN_LAUNCHER.py
pause
"@
$startScriptPath = Join-Path $rootDir "launchers\start_grazyna.bat"
$startScriptContent | Out-File -FilePath $startScriptPath -Encoding utf8
Write-Host "   ✅ Wygenerowano: launchers\start_grazyna.bat"

# 5. Zainstaluj zależności
Write-Host "`n📦 Instalacja zależności..."
try {
    python -m pip install -r $requirementsPath
    Write-Host "   ✅ Zależności zainstalowane pomyślnie"
} catch {
    Write-Host "   ⚠️  Błąd instalacji zależności: $_"
    Write-Host "   💡 Spróbuj ręcznie: python -m pip install rich pyusb pyserial"
}

# 6. Podsumowanie
Write-Host "`n" + "=" * 60
Write-Host "🎉 INSTALACJA ZAKOŃCZONA!"
Write-Host "=" * 60
Write-Host "📂 System zainstalowany w: $rootDir"
Write-Host "`n🚀 Uruchom system:"
Write-Host "   cd $rootDir"
Write-Host "   .\launchers\start_grazyna.bat"

# 7. Opcjonalnie: Uruchom system
$runNow = Read-Host "`nCzy uruchomić system teraz? (T/N)"
if ($runNow -eq "T" -or $runNow -eq "t") {
    Set-Location $rootDir
    & .\launchers\start_grazyna.bat
}