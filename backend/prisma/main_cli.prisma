# -*- coding: utf-8 -*-
from __future__ import annotations
import os
import sys
import json
import time
import subprocess
import threading
from pathlib import Path
from difflib import SequenceMatcher, get_close_matches

BASE_DIR = Path(__file__).resolve().parent
TOOLS_DIR = BASE_DIR / "tools"
PYTHON_EXE = TOOLS_DIR / "PythonPortable" / "python.exe"
NODE_DIR = TOOLS_DIR / "nodejs"
NPM_CMD = NODE_DIR / "npm.cmd"
START_WEB = BASE_DIR / "start_web.ps1"
MANIFEST = BASE_DIR / "tools_manifest.json"
BACKEND_DIR = BASE_DIR / "backend"
FRONTEND_DIR = BASE_DIR / "frontend"

# ===== Command Registry =====
SYSTEM_COMMANDS = {
    "otwórz czat": {"aliases": ["czat", "chat"], "action": "open_chat"},
    "otwórz gpt": {"aliases": ["gpt", "chatgpt", "ai"], "action": "open_gpt"},
    "otwórz analizę danych": {"aliases": ["analiza", "analiza danych", "data", "wykresy"], "action": "open_data_analysis"},
    "uruchom terminal": {"aliases": ["cmd", "powershell", "terminal", "konsola"], "action": "open_terminal"},
    "restart systemu": {"aliases": ["restart", "reboot"], "action": "restart_system"},
    "wyłącz voice": {"aliases": ["mute", "disable voice", "cisza"], "action": "disable_voice"},
    "włącz voice": {"aliases": ["unmute", "enable voice", "głos"], "action": "enable_voice"},
    "otwórz web gui": {"aliases": ["web", "gui web", "panel web", "frontend"], "action": "open_web_gui"},
    "deploy system": {"aliases": ["deploy", "uruchom wszystko", "start system"], "action": "deploy_system"},
    "napraw backend": {"aliases": ["fix backend", "backend fix"], "action": "fix_backend"},
    "pokaż pojazdy": {"aliases": ["pojazdy", "vehicles"], "action": "api_list_vehicles"},
    "status api": {"aliases": ["health", "status"], "action": "api_health"},
    "narzędzia": {"aliases": ["tools", "manifest"], "action": "show_tools"},
}

def _norm(s: str) -> str:
    return (s or "").strip().lower()

class IntentParser:
    def __init__(self, fuzzy_threshold: float = 0.78):
        self.fuzzy_threshold = fuzzy_threshold
        self.index = self._build()

    def _build(self):
        idx = {}
        for cmd, data in SYSTEM_COMMANDS.items():
            idx[_norm(cmd)] = {"action": data.get("action"), "source": "command", "key": cmd}
            for a in data.get("aliases", []):
                idx[_norm(a)] = {"action": data.get("action"), "source": "alias", "key": cmd}
        return idx

    def resolve(self, text: str, return_meta: bool = False):
        t = _norm(text)
        if not t:
            meta = {"action": None, "match": None, "score": 0.0, "source": None}
            return meta if return_meta else None

        if t in self.index:
            m = self.index[t]
            meta = {"action": m["action"], "match": t, "score": 1.0, "source": m["source"], "key": m["key"]}
            return meta if return_meta else m["action"]

        keys = list(self.index.keys())

        pref = [k for k in keys if k.startswith(t)]
        if pref:
            best = sorted(pref, key=len)[0]
            m = self.index[best]
            meta = {"action": m["action"], "match": best, "score": 0.92, "source": f"prefix:{m['source']}", "key": m["key"]}
            return meta if return_meta else m["action"]

        best_k, best_s = None, 0.0
        for k in keys:
            s = SequenceMatcher(None, t, k).ratio()
            if s > best_s:
                best_k, best_s = k, s

        if best_k and best_s >= self.fuzzy_threshold:
            m = self.index[best_k]
            meta = {"action": m["action"], "match": best_k, "score": round(best_s, 3), "source": f"fuzzy:{m['source']}", "key": m["key"]}
            return meta if return_meta else m["action"]

        meta = {"action": None, "match": None, "score": round(best_s, 3), "source": None}
        return meta if return_meta else None

class AutocompleteEngine:
    def __init__(self):
        self.commands = sorted([_norm(k) for k in SYSTEM_COMMANDS.keys()])

    def suggest(self, user_input: str, limit: int = 6):
        t = _norm(user_input)
        if not t:
            return self.commands[:limit]
        pref = [c for c in self.commands if c.startswith(t)]
        if pref:
            return pref[:limit]
        return get_close_matches(t, self.commands, n=limit, cutoff=0.55)

autocomplete_engine = AutocompleteEngine()
intent_parser = IntentParser()

# ===== Voice (auto-off jeśli brak mikrofonu) =====
VOICE_AVAILABLE = False
try:
    import speech_recognition as sr
    import pyttsx3
    try:
        mics = sr.Microphone.list_microphone_names()
        if mics:
            VOICE_AVAILABLE = True
        else:
            print("⚠️ Brak mikrofonu – voice wyłączony")
    except Exception:
        VOICE_AVAILABLE = False
except Exception:
    VOICE_AVAILABLE = False

class VoiceLoop:
    def __init__(self):
        self.enabled = VOICE_AVAILABLE
        self.silent = False
        if self.enabled:
            self.recognizer = sr.Recognizer()
            self.engine = pyttsx3.init()
            self.engine.setProperty("rate", 150)

    def speak(self, text: str):
        if not self.enabled or self.silent:
            print(f"[VOICE] {text}")
            return
        try:
            self.engine.say(text)
            self.engine.runAndWait()
        except Exception:
            print(f"[VOICE] {text}")

    def listen_loop(self):
        if not self.enabled:
            return

        while self.enabled:
            try:
                with sr.Microphone() as source:
                    print("🎙️ Nasłuchiwanie...")
                    self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                    audio = self.recognizer.listen(source, timeout=3)
                    cmd = self.recognizer.recognize_google(audio, language="pl-PL")
                    print(f"🗣️ {cmd}")

                    meta = intent_parser.resolve(cmd, return_meta=True)
                    action = meta.get("action")

                    if action:
                        print(f"⚡ Voice action: {action}")
                        execute_action(action)
                    else:
                        print("❌ Nieznana komenda voice")
            except Exception:
                pass

            time.sleep(2)

# ===== Watchdog usług =====
def _ps_launch(command: str):
    return subprocess.Popen(["powershell.exe", "-NoExit", "-Command", command])

def port_listening(port: int) -> bool:
    try:
        out = subprocess.check_output(
            ["powershell.exe", "-Command",
             f"@(Get-NetTCPConnection -LocalPort {port} -ErrorAction SilentlyContinue | Where-Object {{$_.State -eq 'Listen'}}).Count"],
            text=True
        )
        v = out.strip()
        return v.isdigit() and int(v) > 0
    except Exception:
        return False

class ServiceWatchdog:
    def __init__(self):
        self.enabled = True

    def loop(self):
        while self.enabled:
            try:
                if not port_listening(3001):
                    print("⚠️ Backend down — restart...")
                    _ps_launch(f"cd '{BACKEND_DIR}'; & '{NPM_CMD}' run dev")
                    time.sleep(6)

                if not (port_listening(5173) or port_listening(5174)):
                    print("⚠️ Frontend down — restart...")
                    _ps_launch(f"cd '{FRONTEND_DIR}'; & '{NPM_CMD}' run dev")
                    time.sleep(6)
            except Exception as e:
                print(f"[WATCHDOG] {e}")

            time.sleep(5)

# ===== Self-heal =====
def ensure_python_libs():
    libs = ["speechrecognition", "pyttsx3", "watchdog", "requests"]
    try:
        import importlib.util
        missing = [m for m in libs if importlib.util.find_spec(m) is None]
        if missing:
            print(f"📦 Installing missing Python libs: {missing}")
            subprocess.call([str(PYTHON_EXE), "-m", "pip", "install", *missing])
    except Exception as e:
        print(f"[SELF-HEAL] Python libs: {e}")

def ensure_node_deps():
    try:
        if not (BACKEND_DIR / "node_modules").exists():
            print("📦 Installing backend deps...")
            subprocess.call([str(NPM_CMD), "install"], cwd=str(BACKEND_DIR))
        if not (FRONTEND_DIR / "node_modules").exists():
            print("📦 Installing frontend deps...")
            subprocess.call([str(NPM_CMD), "install"], cwd=str(FRONTEND_DIR))
    except Exception as e:
        print(f"[SELF-HEAL] Node deps: {e}")

# ===== API helper =====
def api_get(path: str):
    try:
        import requests
        r = requests.get(f"http://localhost:3001{path}", timeout=5)
        print(f"[API] {r.status_code} {path}")
        try:
            print(r.json())
        except Exception:
            print(r.text)
    except Exception as e:
        print(f"[API ERROR] {e}")

# ===== Tool manifest =====
def show_tools():
    try:
        if MANIFEST.exists():
            data = json.loads(MANIFEST.read_text(encoding="utf-8"))
            print(json.dumps(data, indent=2, ensure_ascii=False))
        else:
            print("❌ Brak tools_manifest.json")
    except Exception as e:
        print(f"[TOOLS] {e}")

# ===== Execute action =====
voice = None

def execute_action(action: str):
    import webbrowser

    global voice

    if action == "open_terminal":
        subprocess.Popen(["powershell.exe"])
    elif action == "restart_system":
        os.execv(sys.executable, [sys.executable] + sys.argv)
    elif action == "open_gpt":
        webbrowser.open("https://chat.openai.com")
        print("🤖 GPT opened")
    elif action == "open_data_analysis":
        print("📊 Analysis opened")
    elif action == "disable_voice":
        if voice:
            voice.enabled = False
        print("🔇 Voice OFF")
    elif action == "enable_voice":
        if voice and VOICE_AVAILABLE and not voice.enabled:
            voice.enabled = True
            threading.Thread(target=voice.listen_loop, daemon=True).start()
        print("🔊 Voice ON")
    elif action == "open_chat":
        print("💬 CLI chat already active")
    elif action == "open_web_gui":
        subprocess.Popen(["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", str(START_WEB)])
    elif action == "deploy_system":
        subprocess.Popen(["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", str(START_WEB)])
    elif action == "fix_backend":
        subprocess.Popen(["powershell.exe", "-NoExit", "-Command", f"cd '{BACKEND_DIR}'; npm install; npx prisma generate; npm run dev"])
    elif action == "api_list_vehicles":
        api_get("/api/vehicles")
    elif action == "api_health":
        api_get("/api/health")
    elif action == "show_tools":
        show_tools()
    else:
        print(f"[WARN] Unknown action: {action}")

# ===== Main CLI =====
def main():
    print("🚀 GRAŻYNA CLI MODE AKTYWNY")
    print(f"🎤 Voice available: {VOICE_AVAILABLE}")
    print("⌨️ Wpisz komendę; Ctrl+C aby wyjść")
    print("💬 Tryb czatu terminalowego aktywny")

    ensure_python_libs()
    ensure_node_deps()

    global voice
    voice = VoiceLoop()
    if VOICE_AVAILABLE:
        threading.Thread(target=voice.listen_loop, daemon=True).start()

    watchdog = ServiceWatchdog()
    threading.Thread(target=watchdog.loop, daemon=True).start()

    while True:
        try:
            cmd = input("🧠 Komenda: ").strip()
            cmd = cmd.replace("grazyna", "").strip()

            # jawne wykonanie z konsoli:
            if cmd.startswith("!ps "):
                subprocess.call(["powershell.exe", "-NoExit", "-Command", cmd[4:]])
                continue
            if cmd.startswith("!cmd "):
                subprocess.call(["cmd.exe", "/c", cmd[5:]])
                continue
            if cmd.startswith("!py "):
                subprocess.call([str(PYTHON_EXE), "-c", cmd[4:]])
                continue

            if not cmd:
                continue

            suggestions = autocomplete_engine.suggest(cmd)
            meta = intent_parser.resolve(cmd, return_meta=True)
            action = meta.get("action")

            if not suggestions and meta.get("match"):
                suggestions = [meta.get("match")]

            print("💡 Sugestie:", suggestions)
            print(f"🔍 match: {meta.get('match')} | score: {meta.get('score')}")

            if action:
                print(f"⚡ Akcja: {action}")
                execute_action(action)
            else:
                print("❌ Nieznana komenda")

        except KeyboardInterrupt:
            print("👋 Zamykam system")
            break

if __name__ == "__main__":
    main()
