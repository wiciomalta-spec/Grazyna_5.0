# 🚀 GRAZYNA MAX PRO LIVE NEON REAL MAX - Instrukcja Uruchomienia

---

## 📁 **Struktura Katalogów (Gdzie umieścić pliki)**
```
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
```

**📌 Umieść wszystkie pliki w katalogu głównym `Grazyna/` na swoim dysku (np. `C:\Grazyna\` lub `~/Grazyna/`).**

---

---

## 🛠️ **Wymagania Systemowe**
| Wymaganie | Opis |
|-----------|------|
| **System operacyjny** | Windows 10/11, Linux (Ubuntu, Debian) lub macOS |
| **Python** | **3.8 lub nowszy** (zalecany **3.11**) |
| **Pamięć RAM** | Minimum **4 GB** |
| **Miejsce na dysku** | Minimum **500 MB** |
| **Uprawnienia** | **Administrator** (dla dostępu do portów USB/COM) |

---

---

## 📥 **Instalacja Zależności**

### **1. Zainstaluj wymagane pakiety Python**
Uruchom w terminalu (w katalogu `Grazyna/`):

#### **Windows (PowerShell lub CMD):**
```powershell
cd C:\Grazyna
python -m pip install rich pyusb pyserial
```

#### **Linux/macOS (Terminal):**
```bash
cd ~/Grazyna
pip3 install rich pyusb pyserial
```

**⚠️ Uwaga:**
- Na **Linuxie** może być potrzebne zainstalowanie `libusb`:
  ```bash
  sudo apt-get install libusb-1.0-0 python3-usb
  ```
- Na **macOS** użyj:
  ```bash
  brew install libusb
  pip3 install pyusb
  ```

---

---

## 🚀 **Uruchomienie Systemu**

### **1. Uruchom główny launcher**
W terminalu, będąc w katalogu `Grazyna/`, uruchom:

#### **Windows:**
```powershell
cd C:\Grazyna
python GRAZYNA_MAIN_LAUNCHER.py
```

#### **Linux/macOS:**
```bash
cd ~/Grazyna
python3 GRAZYNA_MAIN_LAUNCHER.py
```

---

### **2. Menu Główne**
Po uruchomieniu zobaczysz **menu główne**:

```
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
```

---

### **3. Opcje Menu**
| Opcja | Opis | Działanie |
|-------|------|----------|
| **1** | 🔍 **TP MAX** | Uruchamia zaawansowaną diagnostykę (symulacja) |
| **2** | 🔧 **ECU DIAGNOSTIC** | Diagnostyka ECU (odczyt błędów, identyfikator) |
| **3** | ⚡ **FLASH MODULE** | Flashowanie ECU (wymaga pliku `.bin`) |
| **4** | 🎯 **TUNING MODULE** | Tuning silnika (modyfikacja map) |
| **5** | 📊 **MONITOR** | **Panel LIVE** z monitorowaniem USB/COM |
| **6** | ⚙️ **USTAWIENIA** | Konfiguracja systemu (MAX MODE, połączenia) |
| **7** | 📜 **LOGS** | Wyświetla logi systemowe |
| **8** | 🚪 **WYJŚCIE** | Zamyka program |

---

---

## 🎯 **Panel LIVE (Opcja 5 - MONITOR)**
Po wyborze opcji **5** uruchomi się **Panel LIVE NEON REAL MAX** z:
- **🔌 Monitorowaniem urządzeń USB** (w czasie rzeczywistym)
- **📡 Monitorowaniem portów COM** (w czasie rzeczywistym)
- **📜 Logami systemowymi** (kolorowe, z podziałem na poziomy: INFO, WARNING, ERROR)
- **ℹ️ Informacjami systemowymi** (aktywny moduł, stan systemu, tryb MAX)

**Przykładowy widok panelu:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  GRAŻYNA MAX PRO — MAX MODE | MODUŁ: NONE | STAN: IDLE | URZĄDZENIA: Brak  │
└─────────────────────────────────────────────────────────────────────────────┘
┌─────────────────────┬─────────────────────┐
│ 🔌 USB LIVE         │ 📡 COM LIVE         │
├─────────┬───────────┼─────────┬───────────┤
│ VID:PID │ Producent │ │ Port    │ Opis      │
├─────────┼───────────┼─────────┼───────────┤
│ 1209:C0CA│ MPPS     │ │ COM3   │ MPPS V21 │
└─────────┴───────────┘└─────────┴───────────┘
┌─────────────────────────────────────────────────────────────────────────────┐
│ 📜 SYSTEM LOG                                                                 │
│ [INFO] Start systemu GRAŻYNA MAX PRO LIVE NEON REAL MAX                     │
│ [INFO] Włączono tryb MAX MODE                                                │
│ [INFO] USB NEW → 1209:C0CA                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---
---
## ⚙️ **Konfiguracja Systemu (Opcja 6 - USTAWIENIA)**
Po wyborze opcji **6** zobaczysz menu ustawień:

```
⚙️  USTAWIENIA SYSTEMU GRAŻYNA
===========================================
 [1] 🔄 Tryb MAX MODE - Włącz/Wyłącz
 [2] 📡 Połączenia - Konfiguracja urządzeń
 [3] 📝 Logi - Zarządzanie logami
 [4] 🔙 Powrót do menu głównego
===========================================
```

### **Opcje Ustawień:**
| Opcja | Opis |
|-------|------|
| **1** | **Tryb MAX MODE** – Włącza/wyłącza tryb zaawansowany |
| **2** | **Połączenia** – Skanuje urządzenia USB i porty COM |
| **3** | **Logi** – Wyczyść logi lub eksportuj do pliku |
| **4** | **Powrót** – Wraca do menu głównego |

---
---
## 📜 **Logi Systemowe (Opcja 7 - LOGS)**
Wyświetla **pełną historię logów** zapisaną w pliku `grazyna_system.log`.
Przykładowa zawartość:
```
[2026-05-13 14:30:45] INFO Start systemu GRAŻYNA MAX PRO LIVE NEON REAL MAX
[2026-05-13 14:30:45] INFO Włączono tryb MAX MODE
[2026-05-13 14:30:46] INFO USB NEW → 1209:C0CA
[2026-05-13 14:30:47] INFO COM NEW → COM3
[2026-05-13 14:30:48] INFO TP MAX: start diagnostyki
[2026-05-13 14:30:51] INFO TP MAX: etap 1 OK
[2026-05-13 14:30:53] WARNING TP MAX: lekkie odchylenie parametru
```

---
---
## 🔌 **Podłączanie Urządzeń (MPPS V21, itd.)**
1. **Podłącz urządzenie** (np. **MPPS V21**) przez **USB**.
2. **Uruchom system** (`python GRAZYNA_MAIN_LAUNCHER.py`).
3. **Wybierz opcję 5 (MONITOR)** – panel powinien **automatycznie wykryć urządzenie**.
4. **Sprawdź logi** – powinno pojawić się:
   ```
   [INFO] USB NEW → 1209:C0CA
   ```

**⚠️ Jeśli urządzenie nie jest wykrywane:**
- Sprawdź, czy **sterowniki są zainstalowane** (dla MPPS V21).
- Upewnij się, że **kabel USB jest sprawny**.
- Spróbuj **innego portu USB**.

---
---
## 🛠️ **Rozwiązywanie Problemów**

| Problem | Rozwiązanie |
|---------|-------------|
| **`ModuleNotFoundError: No module named 'rich'`** | Uruchom: `pip install rich pyusb pyserial` |
| **`USBError: Access denied`** | Uruchom system **jako Administrator** (Windows) lub z `sudo` (Linux) |
| **`No module named 'usb'`** | Uruchom: `pip install pyusb` + zainstaluj `libusb` (Linux: `sudo apt-get install libusb-1.0-0`) |
| **Panel nie wyświetla urządzeń** | Sprawdź połączenie USB i sterowniki |
| **Błąd `SerialException`** | Sprawdź, czy port COM jest dostępny (`python -m serial.tools.list_ports`) |
| **System nie uruchamia się** | Sprawdź, czy wszystkie pliki są w poprawnych katalogach |

---
---
## 📌 **Podsumowanie Kroków**
1. **Utwórz katalog `Grazyna/`** (np. `C:\Grazyna\`).
2. **Skopiuj wszystkie pliki** do odpowiednich podkatalogów.
3. **Zainstaluj zależności**:
   ```bash
   pip install rich pyusb pyserial
   ```
4. **Uruchom system**:
   ```bash
   cd Grazyna
   python GRAZYNA_MAIN_LAUNCHER.py
   ```
5. **Wybierz opcję z menu** (np. **5** dla panelu LIVE).

---
---
## 🎉 **Gotowe!**
System **GRAZYNA MAX PRO LIVE NEON REAL MAX** jest teraz **gotowy do użycia**!
- **Monitoruje urządzenia USB/COM** w czasie rzeczywistym.
- **Wyświetla kolorowe logi** z podziałem na poziomy.
- **Obsługuje moduły** (TP MAX, ECU Diagnostic, Flash, Tuning).
- **Działa w trybie MAX MODE** (zaawansowane funkcje).

**🚀 Miłego użytkowania!**