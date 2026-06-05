import json
import importlib
import os


class AIChat:
    def __init__(self):
        self.manifest_path = "manifest.json"
        self.manifest = self._load_manifest()

    # ============================
    #  PUBLICZNA METODA — PANEL
    # ============================
    def ask(self, message: str) -> str:
        logs = []

        # 1. REFINER — analiza kodu, JSON, klas, metod
        if self._is_refiner_mode(message):
            return self._refiner_mode(message, logs)

        # 2. ATK-DATA — JSON w <ATK-DATA>
        if "<ATK-DATA>" in message:
            return self._handle_atk_data(message)

        # 3. Normalna komenda → szukamy akcji
        action = self._find_action(message)
        if not action:
            return "Nie rozpoznano komendy."

        return self.execute_action(action, message)

    # ============================
    #  RELOAD — AUTO-RELOAD
    # ============================
    def reload(self):
        self.__init__()

    # ============================
    #  MANIFEST
    # ============================
    def _load_manifest(self):
        if not os.path.exists(self.manifest_path):
            return {}
        try:
            with open(self.manifest_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
            return {}

    def _save_manifest(self):
        with open(self.manifest_path, "w", encoding="utf-8") as f:
            json.dump(self.manifest, f, indent=4, ensure_ascii=False)

    # ============================
    #  WYKRYWANIE AKCJI
    # ============================
    def _find_action(self, message: str):
        for action in self.manifest:
            if action.lower() in message.lower():
                return action
        return None

    # ============================
    #  WYKONYWANIE AKCJI
    # ============================
    def execute_action(self, action: str, message: str):
        if action not in self.manifest:
            return f"Brak akcji: {action}"

        module_name = self.manifest[action]["module"]
        method_name = self.manifest[action]["method"]

        try:
            module = importlib.import_module(module_name)
            method = getattr(module, method_name)
            return method(message)
        except Exception as e:
            return f"Błąd wykonania akcji {action}: {e}"

    # ============================
    #  ATK-DATA — JSON
    # ============================
    def _handle_atk_data(self, text: str) -> str:
        try:
            inside = text.split("<ATK-DATA>")[1].split("</ATK-DATA>")[0]
            return f"[ATK-DATA] Odebrano dane:\n{inside}"
        except:
            return "[ATK-DATA] Błąd parsowania."

    # ============================
    #  TRYB REFINER
    # ============================
    def _is_refiner_mode(self, text: str) -> bool:
        return any(x in text for x in ["class ", "def ", "{", "}"])

    def _refiner_mode(self, message: str, logs: list) -> str:
        text = message.strip()
        logs.append("[ATK-REFINER] Start analizy tekstu")

        # JSON
        json_blocks = []
        current = []
        depth = 0
        for ch in text:
            if ch == "{":
                depth += 1
            if depth > 0:
                current.append(ch)
            if ch == "}":
                depth -= 1
                if depth == 0:
                    block = "".join(current).strip()
                    json_blocks.append(block)
                    current = []
        if json_blocks:
            logs.append(f"[ATK-REFINER] Wykryto {len(json_blocks)} bloków JSON → przekazuję do ATK-DATA")
            fake = "<ATK-DATA>\n" + "\n".join(json_blocks) + "\n</ATK-DATA>"
            return self._handle_atk_data(fake)

        # klasy/metody
        import re
        classes = re.findall(r"class\s+([A-Za-z_][A-Za-z0-9_]*)", text)
        methods = re.findall(r"def\s+([A-Za-z_][A-Za-z0-9_]*)", text)

        if classes or methods:
            logs.append(f"[ATK-REFINER] Wykryto klasy: {classes}")
            logs.append(f"[ATK-REFINER] Wykryto metody: {methods}")
            for m in methods:
                if m.startswith("_"):
                    continue
                action = f"refiner.{m}"
                module = "rings.ring_refiner.refiner"
                if action not in self.manifest:
                    self.manifest[action] = {"module": module, "method": m}
                    self._save_manifest()
                    logs.append(f"[ATK-REFINER] Dodano akcję: {action}")
            logs.append("[ATK-REFINER] Analiza zakończona")
            return "\n".join(logs)

        logs.append("[ATK-REFINER] Brak elementów do analizy")
        return "\n".join(logs)