# pylint: skip-file
# Module for holding types, for easy importing into the rest of the codebase
from __future__ import annotations

# The only three things that should be available during runtime.
from typing import TYPE_CHECKING, cast, overload

if TYPE_CHECKING:
    import re
    import sys
    from types import EllipsisType, UnionType
    from typing import (
        AbstractSet,
        Any,
        AnyStr,
        Awaitable,
        Callable,
        DefaultDict,
        Deque,
        FrozenSet,
        Generator,
        Generic,
        Iterable,
        Iterator,
        Literal,
        Mapping,
        MutableMapping,
        MutableSequence,
        NamedTuple,
        NewType,
        Protocol,
        Sequence,
        TextIO,
        TypeAlias,
        TypedDict,
        TypeGuard,
        TypeVar,
    )

    from _typeshed import SupportsKeysAndGetItem
    from typing_extensions import (
        NotRequired,
        Required,
    )

    from .parsing import ParseConfig
    from .printing import PrintConfig
    from .stream import Stream
    from .types import (
        Binary,
        Bool,
        Decimal,
        Document,
        ExactValue,
        Hex,
        Node,
        Null,
        Numberish,
        Octal,
        RawString,
        String,
        Stringish,
        Value,
    )

    TagKey = str | None | EllipsisType | re.Pattern | Callable[[str | None], bool]
    NameKey = str | None | EllipsisType | re.Pattern | Callable[[str | None], bool]
    NodeKey = NameKey | tuple[TagKey, NameKey]

    if sys.version_info >= (3, 10):
        _ClassInfo: TypeAlias = type | UnionType | tuple[_ClassInfo, ...]
    else:
        _ClassInfo: TypeAlias = type | tuple[_ClassInfo, ...]
    TypeKey: TypeAlias = EllipsisType | _ClassInfo
    ValueKey = TagKey | tuple[TagKey, TypeKey]

    KDLAny: TypeAlias = Document | Node | KDLValue
    KDLValue: TypeAlias = (
        Value | Binary | Bool | Decimal | ExactValue | Hex | Null | Numberish | Octal | RawString | String | Stringish
    )

    import datetime
    import decimal
    import ipaddress
    import urllib
    import uuid

    KDLishValue: TypeAlias = (
        KDLValue
        | None
        | bool
        | String
        | int
        | float
        | decimal.Decimal
        | datetime.time
        | datetime.date
        | datetime.datetime
        | ipaddress.IPv4Address
        | ipaddress.IPv6Address
        | urllib.parse.ParseResult
        | uuid.UUID
        | re.Pattern
        | bytes
    )
