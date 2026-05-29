# -*- coding: utf-8 -*-
from __future__ import annotations

from difflib import SequenceMatcher
from typing import Optional, Dict, Any, Tuple

from .command_registry import SYSTEM_COMMANDS


def _norm(s: str) -> str:
    return (s or "").strip().lower()


class IntentParser:
    def __init__(self, fuzzy_threshold: float = 0.78):
        self.fuzzy_threshold = fuzzy_threshold
        self._index = self._build_index()

    def _build_index(self) -> Dict[str, Dict[str, Any]]:
        idx: Dict[str, Dict[str, Any]] = {}
        for cmd, data in SYSTEM_COMMANDS.items():
            idx[_norm(cmd)] = {"action": data.get("action"), "source": "command", "key": cmd}
            for a in data.get("aliases", []) or []:
                idx[_norm(a)] = {"action": data.get("action"), "source": "alias", "key": cmd}
        return idx

    def refresh(self):
        self._index = self._build_index()

    def resolve(self, text: str, return_meta: bool = False):
        action, meta = self._resolve_internal(text)
        return meta if return_meta else action

    def _resolve_internal(self, text: str) -> Tuple[Optional[str], Dict[str, Any]]:
        t = _norm(text)
        if not t:
            return None, {"action": None, "match": None, "score": 0.0, "source": None}

        if t in self._index:
            m = self._index[t]
            return m["action"], {"action": m["action"], "match": t, "score": 1.0, "source": m["source"], "key": m["key"]}

        keys = list(self._index.keys())

        pref = [k for k in keys if k.startswith(t)]
        if pref:
            best = sorted(pref, key=len)[0]
            m = self._index[best]
            return m["action"], {"action": m["action"], "match": best, "score": 0.92, "source": f"prefix:{m['source']}", "key": m["key"]}

        best_k = None
        best_score = 0.0
        for k in keys:
            s = SequenceMatcher(None, t, k).ratio()
            if s > best_score:
                best_score = s
                best_k = k

        if best_k and best_score >= self.fuzzy_threshold:
            m = self._index[best_k]
            return m["action"], {"action": m["action"], "match": best_k, "score": round(best_score, 3), "source": f"fuzzy:{m['source']}", "key": m["key"]}

        return None, {"action": None, "match": None, "score": round(best_score, 3), "source": None}
