"""
GRAZYNA MAX PRO LIVE NEON REAL MAX - Pełny System
Struktura:
Grazyna/
├─ core/
│  ├─ __init__.py
│  ├─ state.py
│  └─ logger.py
├─ ui/
│  ├─ __init__.py
│  └─ panel_live/
│     ├─ __init__.py
│     └─ panel_live_neon_real_max.py
├─ modules/
│  ├─ __init__.py
│  └─ tp_max.py
└─ GRAZYNA_MAIN_LAUNCHER.py
"""

# === core/__init__.py ===
"""
# core package init
"""

# === core/state.py ===
ACTIVE_MODULE = "NONE"
SYSTEM_STATE = "IDLE"
MAX_MODE = False

def set_active_module(name: str):
    global ACTIVE_MODULE
    ACTIVE_MODULE = name

def set_system_state(state: str):
    global SYSTEM_STATE
    SYSTEM_STATE = state

def enable_max_mode():
    global MAX_MODE
    MAX_MODE = True

def disable_max_mode():
    global MAX_MODE
    MAX_MODE = False

def is_max_mode() -> bool:
    return MAX_MODE

# === core/logger.py ===
from datetime import datetime

LIVE_PANEL_HOOK = None

def attach_live_panel(hook):
    global LIVE_PANEL_HOOK
    LIVE_PANEL_HOOK = hook

def log(level: str, msg: str):
    ts = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}] {level} {msg}"
    print(line)
    if LIVE_PANEL_HOOK:
        LIVE_PANEL_HOOK(level, msg)

# === ui/__init__.py ===
"""
# ui package init
"""

# === ui/panel_live/__init__.py ===
"""
# panel_live package init
"""

# === ui/panel_live/panel_live_neon_real_max.py ===
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

from core.state import ACTIVE_MODULE, SYSTEM_STATE, is_max_mode
from core.logger import attach_live_panel

console = Console()

class GrazynaNeonRealMax:
    def __init__(self):
        self.prev_usb = {}
        self.prev_com = {}
        self.logs = []
        attach_live_panel(self.log_hook)

    def log_hook(self, level, msg):
        self.logs.append((level, msg))
        if len(self.logs) > 300:
            self.logs.pop(0)

    def scan_usb(self):
        devices = usb.core.find(find_all=True)
        result = {}
        for dev in devices:
            key = f"{dev.idVendor:04X}:{dev.idProduct:04X}"
            result[key] = {
                "vid": f"{dev.idVendor:04X}",
                "pid": f"{dev.idProduct:04X}",
                "man": usb.util.get_string(dev, dev.iManufacturer) or "N/A",
                "prod": usb.util.get_string(dev, dev.iProduct) or "N/A",
                "sn": usb.util.get_string(dev, dev.iSerialNumber) or "N/A"
            }
        return result

    def scan_com(self):
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
        for k in now:
            if k not in prev:
                self.logs.append(("INFO", f"{label} NEW → {k}"))
        for k in prev:
            if k not in now:
                self.logs.append(("WARNING", f"{label} LOST → {k}"))

    def build_status_bar(self):
        mode = "MAX MODE" if is_max_mode() else "STANDARD"
        text = Text(
            f" GRAŻYNA MAX PRO — {mode} | MODUŁ: {ACTIVE_MODULE} | STAN: {SYSTEM_STATE} ",
            style="bold magenta on #111122"
        )
        return Panel(text, border_style="bright_magenta", box=box.ROUNDED)

    def build_usb_table(self, usb):
        table = Table(title="USB LIVE", border_style="bright_cyan", style="cyan", box=box.SQUARE)
        table.add_column("VID")
        table.add_column("PID")
        table.add_column("Manufacturer")
        table.add_column("Product")
        table.add_column("SN")
        for d in usb.values():
            table.add_row(d["vid"], d["pid"], d["man"], d["prod"], d["sn"])
        return table

    def build_com_table(self, com):
        table = Table(title="COM LIVE", border_style="bright_magenta", style="magenta", box=box.SQUARE)
        table.add_column("Port")
        table.add_column("Desc")
        table.add_column("Man")
        table.add_column("SN")
        table.add_column("VID:PID")
        for d in com.values():
            table.add_row(d["port"], d["desc"], d["man"], d["sn"], d["vidpid"])
        return table

    def build_log_panel(self):
        table = Table(show_header=False, border_style="yellow", box=box.MINIMAL)
        table.add_column("Log")
        for level, msg in self.logs[-18:]:
            color = {
                "INFO": "bright_green",
                "DEBUG": "bright_blue",
                "WARNING": "yellow",
                "ERROR": "bright_red"
            }.get(level, "white")
            table.add_row(Text(f"[{level}] {msg}", style=color))
        return Panel(table, title="SYSTEM LOG", border_style="yellow", box=box.ROUNDED)

    def build_layout(self, usb, com):
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
        with Live(console=console, refresh_per_second=8, screen=True):
            while True:
                usb_now = self.scan_usb()
                com_now = self.scan_com()

                self.detect_changes(usb_now, self.prev_usb, "USB")
                self.detect_changes(com_now, self.prev_com, "COM")

                layout = self.build_layout(usb_now, com_now)
                console.print(layout)

                self.prev_usb = usb_now
                self.prev_com = com_now

                time.sleep(1)
                console.clear()

# === modules/__init__.py ===
"""
# modules package init
"""

# === modules/tp_max.py ===
from core.state import set_active_module, set_system_state, enable_max_mode
from core.logger import log
import time

def run_tp_max():
    enable_max_mode()
    set_active_module("TP MAX")
    set_system_state("RUNNING")
    log("INFO", "TP MAX: start diagnostyki")

    time.sleep(3)
    log("INFO", "TP MAX: etap 1 OK")
    time.sleep(2)
    log("WARNING", "TP MAX: lekkie odchylenie parametru")
    time.sleep(2)
    log("ERROR", "TP MAX: błąd testowy (symulacja)")

    set_system_state("IDLE")
    log("INFO", "TP MAX: koniec diagnostyki")

# === GRAZYNA_MAIN_LAUNCHER.py ===
from core.state import enable_max_mode
from core.logger import log
from ui.panel_live.panel_live_neon_real_max import GrazynaNeonRealMax
from modules.tp_max import run_tp_max
import threading
import time

def start_panel():
    panel = GrazynaNeonRealMax()
    panel.run()

def start_tp_max_delayed():
    time.sleep(2)
    run_tp_max()

if __name__ == "__main__":
    enable_max_mode()
    log("INFO", "Start Grażyna MAX PRO REAL MAX MODE")

    t_panel = threading.Thread(target=start_panel, daemon=True)
    t_panel.start()

    t_tp = threading.Thread(target=start_tp_max_delayed, daemon=True)
    t_tp.start()

    while True:
        time.sleep(1)