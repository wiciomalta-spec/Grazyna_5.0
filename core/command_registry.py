SYSTEM_COMMANDS = {
    "otwórz gpt": {
        "aliases": ["gpt", "chatgpt", "ai"],
        "action": "open_gpt"
    },

    "otwórz analizę danych": {
        "aliases": ["analiza", "data", "wykresy"],
        "action": "open_data_analysis"
    },

    "restart systemu": {
        "aliases": ["restart", "reboot"],
        "action": "restart_system"
    },

    "wyłącz voice": {
        "aliases": ["mute", "disable voice"],
        "action": "disable_voice"
    },

    "uruchom terminal": {
        "aliases": ["cmd", "powershell", "terminal"],
        "action": "open_terminal"
    }
}
