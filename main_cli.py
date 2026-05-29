# -*- coding: utf-8 -*-
from __future__ import annotations
import os
import sys
import subprocess
import threading

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from core.autocomplete import AutocompleteEngine
from core.intent_parser import IntentParser

autocomplete_engine = AutocompleteEngine()
intent_parser = IntentParser()

VOICE_AVAILABLE = False
try:
    import speech_recognition as sr
    import pyttsx3
    VOICE_AVAILABLE = True
except Exception:
    VOICE_AVAILABLE = False


def execute_action(action: str):
    actions = {
        "open_terminal": lambda: subprocess.Popen(["powershell.exe"]),
        "restart_system": lambda: os.execv(sys.executable, [sys.executable] + sys.argv),
        "open_gpt": lambda: print("🤖 GPT opened"),
        "open_data_analysis": lambda: print("📊 Analysis opened"),
        "disable_voice": lambda: print("🔇 Voice OFF"),
        "enable_voice": lambda: print("🔊 Voice ON"),
        "open_chat": lambda: print("💬 Chat opened"),
        "open_web_gui": lambda: subprocess.Popen(["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", os.path.join(BASE_DIR, "start_web.ps1")]),
    }
    fn = actions.get(action)
    if fn:
        print(f"[ACTION] {action}")
        fn()
    else:
        print(f"[WARN] Unknown action: {action}")


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
            print("⚠️ Voice disabled: speech_recognition/pyttsx3 unavailable")
            return
        while self.enabled:
            try:
                with sr.Microphone() as source:
                    print("🎙️ Nasłuchiwanie...")
                    self.recognizer.adjust_for_ambient_noise(source)
                    audio = self.recognizer.listen(source, timeout=3)
                    cmd = self.recognizer.recognize_google(audio, language="pl-PL")
                    print(f"🗣️ {cmd}")
                    meta = intent_parser.resolve(cmd, return_meta=True)
                    action = meta.get("action")
                    if action:
                        print(f"⚡ Voice action: {action}")
                        execute_action(action)
                    else:
                        print("❌ Voice: nieznana komenda")
            except Exception:
                pass


def main():
    print("🚀 GRAŻYNA CLI MODE AKTYWNY")
    print(f"🎤 Voice available: {VOICE_AVAILABLE}")
    print("⌨️ Wpisz komendę lub Ctrl+C aby wyjść")

    voice = VoiceLoop()
    if VOICE_AVAILABLE:
        threading.Thread(target=voice.listen_loop, daemon=True).start()

    while True:
        try:
            cmd = input("🧠 Komenda: ").strip()
            cmd = cmd.replace("grazyna", "").strip()

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
