from command_registry import SYSTEM_COMMANDS


class IntentParser:

    def resolve(self, text: str):

        text = text.lower().strip()

        for command, data in SYSTEM_COMMANDS.items():

            if text == command:
                return data["action"]

            for alias in data.get("aliases", []):

                if text == alias:
                    return data["action"]

        return None
