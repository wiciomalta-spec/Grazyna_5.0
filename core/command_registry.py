# -*- coding: utf-8 -*-

SYSTEM_COMMANDS = {
    "otwórz czat": {
        "aliases": ["czat", "chat"],
        "action": "open_chat",
    },
    "otwórz gpt": {
        "aliases": ["gpt", "chatgpt", "ai"],
        "action": "open_gpt",
    },
    "otwórz analizę danych": {
        "aliases": ["analiza", "data", "wykresy", "analiza danych"],
        "action": "open_data_analysis",
    },
    "uruchom terminal": {
        "aliases": ["cmd", "powershell", "terminal", "konsola"],
        "action": "open_terminal",
    },
    "restart systemu": {
        "aliases": ["restart", "reboot"],
        "action": "restart_system",
    },
    "wyłącz voice": {
        "aliases": ["mute", "disable voice", "wycisz", "cisza"],
        "action": "disable_voice",
    },
    "włącz voice": {
        "aliases": ["unmute", "enable voice", "głos"],
        "action": "enable_voice",
    },
    "otwórz web gui": {
        "aliases": ["web", "gui web", "panel web", "frontend"],
        "action": "open_web_gui",
    },
}
