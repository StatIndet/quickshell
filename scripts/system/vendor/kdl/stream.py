from __future__ import annotations

from dataclasses import dataclass

from . import t


@dataclass
class Stream:
    _chars: str
    config: t.ParseConfig

    def __getitem__(self, key: int | slice) -> str:
        try:
            return self._chars[key]
        except IndexError:
            return ""

    def eof(self, index: int) -> bool:
        return index >= len(self._chars)
