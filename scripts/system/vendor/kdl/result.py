from __future__ import annotations

from typing import NamedTuple

from . import t


class Failure:
    pass


class Result(NamedTuple):
    value: t.Any
    end: int

    @property
    def valid(self) -> bool:
        return self.value is not Failure

    @staticmethod
    def fail(index: int) -> Result:
        return Result(Failure, index)
