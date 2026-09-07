from __future__ import annotations

from dataclasses import dataclass, field

from . import parsefuncs, t

if t.TYPE_CHECKING:
    from .errors import ParseFragment
    from .types import Node, Value

    ValueConverterT: t.TypeAlias = t.Callable[[Value, ParseFragment], t.Any]
    NodeConverterT: t.TypeAlias = t.Callable[[Node, ParseFragment], t.Any]


class Parser:
    def __init__(
        self,
        parseConfig: ParseConfig | None = None,
        printConfig: t.PrintConfig | None = None,
    ) -> None:
        self.parseConfig = parseConfig
        self.printConfig = printConfig

    def parse(self, chars: str, config: ParseConfig | None = None) -> t.Document:
        doc = parsefuncs.parse(chars, config or self.parseConfig or defaults)
        doc.printConfig = self.printConfig
        return doc


@dataclass
class ParseConfig:
    nativeUntaggedValues: bool = True
    nativeTaggedValues: bool = True
    valueConverters: dict[t.ValueKey, ValueConverterT] = field(default_factory=dict)
    nodeConverters: dict[t.NodeKey, NodeConverterT] = field(
        default_factory=dict,
    )


defaults = ParseConfig()
