from __future__ import annotations

import base64
import datetime
import decimal
import ipaddress
import re
import urllib.parse
import uuid

from . import t, types

if t.TYPE_CHECKING:
    from .errors import ParseFragment


def toNative(val: t.Value, pf: ParseFragment) -> t.KDLishValue:
    if isinstance(val, types.Numberish):
        if val.tag == "i8":
            return i8(val, pf)
        if val.tag == "i16":
            return i16(val, pf)
        if val.tag == "i32":
            return i32(val, pf)
        if val.tag == "i64":
            return i64(val, pf)
        if val.tag == "u8":
            return u8(val, pf)
        if val.tag == "u16":
            return u16(val, pf)
        if val.tag == "u32":
            return u32(val, pf)
        if val.tag == "u64":
            return u64(val, pf)
        if val.tag in ("f32", "f64"):
            return int(val.value)
        if val.tag in ("decimal64", "decimal128"):
            return decim(val, pf)
    if isinstance(val, types.Stringish):
        if val.tag == "date-time":
            return dateTime(val, pf)
        if val.tag == "time":
            return time(val, pf)
        if val.tag == "date":
            return date(val, pf)
        if val.tag == "decimal":
            return decim(val, pf)
        if val.tag == "ipv4":
            return ipv4(val, pf)
        if val.tag == "ipv6":
            return ipv6(val, pf)
        if val.tag == "url":
            return url(val, pf)
        if val.tag == "uuid":
            return _uuid(val, pf)
        if val.tag == "regex":
            return regex(val, pf)
        if val.tag == "base64":
            return b64(val, pf)
    return val


def i8(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**7
    if not (-limit <= val.value < limit):
        msg = f"{val.value} doesn't fit in an i8."
        raise pf.error(msg)
    return int(val.value)


def i16(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**15
    if not (-limit <= val.value < limit):
        msg = f"{val.value} doesn't fit in an i16."
        raise pf.error(msg)
    return int(val.value)


def i32(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**31
    if not (-limit <= val.value < limit):
        msg = f"{val.value} doesn't fit in an i32."
        raise pf.error(msg)
    return int(val.value)


def i64(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**63
    if not (-limit <= val.value < limit):
        msg = f"{val.value} doesn't fit in an i64."
        raise pf.error(msg)
    return int(val.value)


def u8(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**8
    if not (0 <= val.value < limit):
        msg = f"{val.value} doesn't fit in a u8."
        raise pf.error(msg)
    return int(val.value)


def u16(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**16
    if not (0 <= val.value < limit):
        msg = f"{val.value} doesn't fit in a u16."
        raise pf.error(msg)
    return int(val.value)


def u32(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**32
    if not (0 <= val.value < limit):
        msg = f"{val.value} doesn't fit in a u32."
        raise pf.error(msg)
    return int(val.value)


def u64(val: t.Numberish, pf: ParseFragment) -> int:
    limit = 2**64
    if not (0 <= val.value < limit):
        msg = f"{val.value} doesn't fit in a u64."
        raise pf.error(msg)
    return int(val.value)


def decim(val: t.Value, pf: ParseFragment) -> decimal.Decimal:
    if isinstance(val, types.Numberish):
        chars = pf.fragment.replace("_", "")
    else:
        chars = val.value
    try:
        return decimal.Decimal(chars)
    except decimal.InvalidOperation as exc:
        msg = f"Couldn't parse a decimal from {pf.fragment}."
        raise pf.error(msg) from exc


def dateTime(val: t.Stringish, pf: ParseFragment) -> datetime.datetime:
    try:
        return datetime.datetime.fromisoformat(val.value)
    except ValueError as exc:
        msg = f"Couldn't parse a date-time from {pf.fragment}."
        raise pf.error(msg) from exc


def time(val: t.Stringish, pf: ParseFragment) -> datetime.time:
    try:
        return datetime.time.fromisoformat(val.value)
    except ValueError as exc:
        msg = f"Couldn't parse a date-time from {pf.fragment}."
        raise pf.error(msg) from exc


def date(val: t.Stringish, pf: ParseFragment) -> datetime.date:
    try:
        return datetime.date.fromisoformat(val.value)
    except ValueError as exc:
        msg = f"Couldn't parse a date from {pf.fragment}."
        raise pf.error(msg) from exc


def ipv4(val: t.Stringish, pf: ParseFragment) -> ipaddress.IPv4Address:
    try:
        return ipaddress.IPv4Address(val.value)
    except ipaddress.AddressValueError as exc:
        msg = f"Couldn't parse an IPv4 address from {pf.fragment}."
        raise pf.error(msg) from exc


def ipv6(val: t.Stringish, pf: ParseFragment) -> ipaddress.IPv6Address:
    try:
        return ipaddress.IPv6Address(val.value)
    except ipaddress.AddressValueError as exc:
        msg = f"Couldn't parse an IPv6 address from {pf.fragment}."
        raise pf.error(msg) from exc


def url(val: t.Stringish, pf: ParseFragment) -> urllib.parse.ParseResult:
    try:
        return t.cast("urllib.parse.ParseResult", urllib.parse.urlparse(val.value))
    except ValueError as exc:
        msg = f"Couldn't parse a url from {pf.fragment}."
        raise pf.error(msg) from exc


def _uuid(val: t.Stringish, pf: ParseFragment) -> uuid.UUID:
    try:
        return uuid.UUID(val.value)
    except Exception as exc:
        msg = f"Couldn't parse a UUID from {pf.fragment}."
        raise pf.error(msg) from exc


def regex(val: t.Stringish, pf: ParseFragment) -> re.Pattern:
    try:
        return re.compile(val.value)
    except Exception as exc:
        msg = f"Couldn't parse a regex from {pf.fragment}."
        raise pf.error(msg) from exc


def b64(val: t.Stringish, pf: ParseFragment) -> bytes:
    try:
        return base64.b64decode(val.value.encode("utf-8"), validate=True)
    except Exception as exc:
        msg = "Couldn't parse base64."
        raise pf.error(msg) from exc
