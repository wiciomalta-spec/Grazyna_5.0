from difflib import get_close_matches
from command_registry import SYSTEM_COMMANDS


class AutocompleteEngine:

    def __init__(self):
        self.commands = list(SYSTEM_COMMANDS.keys())

        self.alias_map = {}

        for cmd, data in SYSTEM_COMMANDS.items():
            for alias in data.get("aliases", []):
                self.alias_map[alias] = cmd

    def suggest(self, text: str):

        text = text.lower().strip()

        suggestions = []

        for cmd in self.commands:
            if cmd.startswith(text):
                suggestions.append(cmd)

        for alias, real_cmd in self.alias_map.items():
            if alias.startswith(text):
                suggestions.append(real_cmd)

        fuzzy = get_close_matches(
            text,
            self.commands,
            n=5,
            cutoff=0.4
        )

        suggestions.extend(fuzzy)

        return list(dict.fromkeys(suggestions))[:5]
