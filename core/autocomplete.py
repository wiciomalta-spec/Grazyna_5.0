# -*- coding: utf-8 -*-
from __future__ import annotations

from difflib import get_close_matches
from typing import List

from .command_registry import SYSTEM_COMMANDS


def _norm(s: str) -> str:
    return (s or "").strip().lower()


class AutocompleteEngine:
    def __init__(self):
        self._commands = self._build_list()

    def _build_list(self) -> List[str]:
        return sorted([_norm(k) for k in SYSTEM_COMMANDS.keys()])

    def refresh(self):
        self._commands = self._build_list()

    def suggest(self, user_input: str, limit: int = 6) -> List[str]:
        t = _norm(user_input)
        if not t:
            return self._commands[:limit]

        pref = [c for c in self._commands if c.startswith(t)]
        if pref:
            return pref[:limit]

        return get_close_matches(t, self._commands, n=limit, cutoff=0.55)
