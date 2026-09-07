from __future__ import annotations

from . import t


class ParseError(Exception):
    def __init__(self, s: str | t.Stream, i: int, msg: str) -> None:
        self.line, self.col = lineCol(s, i)
        self.msg = f"{self.line}:{self.col} parse error:"
        if "\n" in msg:
            self.msg += "\n" + msg
        elif len(self.msg) + len(msg) + 1 > 78:
            self.msg += "\n  " + msg
        else:
            self.msg += " " + msg
        super().__init__(self.msg)


def lineCol(s: str | t.Stream, index: int) -> tuple[int, int]:
    """Determines the line and column from an index."""
    line = 1
    col = 1
    for i in range(index):
        if s[i] == "\n":
            line += 1
            col = 1
            continue
        col += 1
    return line, col


class ParseFragment:
    def __init__(self, fragment: str, s: t.Stream, i: int) -> None:
        self.fragment = fragment
        self._s = s
        self._i = i

    def error(self, msg: str) -> ParseError:
        return ParseError(self._s, self._i, msg)
