from __future__ import annotations

from . import converters, parsing, t, types
from .errors import ParseError, ParseFragment
from .result import Failure, Result
from .stream import Stream


def parse(input: str, config: t.ParseConfig | None = None) -> t.Document:
    if config is None:
        config = parsing.defaults
    doc = types.Document()
    s = Stream(input, config)
    _, i = parseLinespace(s, 0)
    while not s.eof(i):
        node, i = parseNode(s, i)
        if node is Failure:
            raise ParseError(s, i, "Expected a node")
        if node:
            doc.nodes.append(node)
        _, i = parseLinespace(s, i)
    return doc


def parseNode(s: Stream, start: int) -> Result:
    i = start

    sd, i = parseSlashDash(s, i)
    if sd is Failure:
        sd = False

    # tag?
    tag, i = parseTag(s, i)
    if tag is Failure:
        tag = None

    # name
    name, i = parseIdent(s, i)
    if name is Failure:
        return Result.fail(start)

    nameEnd = i

    node = types.Node(tag=tag, name=name)

    # props and args
    while True:
        space, i = parseNodespace(s, i)
        if space is Failure:
            break
        entity, i = parseEntity(s, i)
        if entity is Failure:
            break
        if entity is None:
            continue
        if entity[0] is None:
            node.args.append(entity[1])
        else:
            node.props[entity[0]] = entity[1]

    _, i = parseNodespace(s, i)

    nodes, i = parseNodeChildren(s, i)
    if nodes is not Failure:
        node.nodes = nodes
        node.children_end = i - 1

    _, i = parseNodespace(s, i)
    _, i = parseNodeTerminator(s, i)

    node.source_start = start
    node.source_end = i
    if sd:
        return Result(None, i)
    else:
        for key, converter in s.config.nodeConverters.items():
            if node.matchesKey(key):
                node = converter(
                    node,
                    ParseFragment(s[start:nameEnd], s, start),
                )
                if node == NotImplemented:
                    continue
                else:
                    break
        return Result(node, i)


def parseNodeChildren(s: Stream, start: int) -> Result:
    sd, i = parseSlashDash(s, start)
    if sd is Failure:
        sd = False

    if s[i] != "{":
        return Result.fail(start)
    i += 1
    nodes = []
    while True:
        _, i = parseLinespace(s, i)
        node, i = parseNode(s, i)
        if node is Failure:
            break
        if node is not None:
            nodes.append(node)
    _, i = parseLinespace(s, i)
    if s.eof(i):
        raise ParseError(s, start, "Hit EOF while searching for end of child list")
    if s[i] != "}":
        raise ParseError(s, i, "Junk between end of child list and closing }")
    if sd:
        return Result(None, i + 1)
    else:
        return Result(nodes, i + 1)


def parseTag(s: Stream, start: int) -> Result:
    if s[start] != "(":
        return Result.fail(start)
    tag, end = parseIdent(s, start + 1)
    if tag is Failure:
        return Result.fail(start)
    if s[end] != ")":
        raise ParseError(s, end, "Junk between tag ident and closing paren.")
    return Result(tag, end + 1)


def parseIdent(s: Stream, start: int) -> Result:
    string, i = parseString(s, start)
    if string is not Failure:
        return Result(string.value, i)
    return parseBareIdent(s, start)


def parseBareIdent(s: Stream, start: int) -> Result:
    res, i = parseIdentStart(s, start)
    if res is Failure:
        return Result.fail(start)
    while isIdentChar(s[i]):
        i += 1
    ident = s[start:i]
    if isKeyword(ident):
        return Result.fail(start)
    return Result(ident, i)


def parseIdentStart(s: Stream, start: int) -> Result:
    if isDigit(s[start]) or (isSign(s[start]) and isDigit(s[start + 1])):
        return Result.fail(start)
    if not isIdentChar(s[start]):
        return Result.fail(start)
    return Result(s[start], start + 1)


def parseNodeTerminator(s: Stream, start: int) -> Result:
    res = parseNewline(s, start)
    if res.valid:
        return res
    res = parseSingleLineComment(s, start)
    if res.valid:
        return res
    if s[start] == ";":
        return Result(";", start + 1)
    if s.eof(start) or s[start] == "}":
        return Result(True, start)
    raise ParseError(s, start, "Junk after node, before terminator.")


def parseEntity(s: Stream, start: int) -> Result:
    sd, i = parseSlashDash(s, start)
    if sd is Failure:
        sd = False

    ent, i = parseProperty(s, i)
    if ent is Failure:
        ent, i = parseValue(s, i)
        if ent is Failure:
            return Result.fail(start)
    if sd:
        return Result(None, i)
    else:
        return Result(ent, i)


def parseProperty(s: Stream, start: int) -> Result:
    key, i = parseIdent(s, start)
    if key is Failure:
        return Result.fail(start)
    if s[i] != "=":
        # property name might be a string,
        # so this isn't point-of-no-return yet
        return Result.fail(start)
    entity, i = parseValue(s, i + 1)
    if entity is Failure:
        raise ParseError(s, i, "Expected value after prop=.")
    return Result((key, entity[1]), i)


def parseValue(s: Stream, start: int) -> Result:
    tag, i = parseTag(s, start)
    if tag is Failure:
        tag = None

    valueStart = i
    val, i = parseNumber(s, i)
    if val is Failure:
        val, i = parseKeyword(s, i)
        if val is Failure:
            val, i = parseString(s, i)
    val.tag = tag
    if val is not Failure:
        for key, converter in s.config.valueConverters.items():
            if val.matchesKey(key):
                val = converter(
                    val,
                    ParseFragment(s[valueStart:i], s, i),
                )
                if val == NotImplemented:
                    continue
                else:
                    break
        else:
            if tag is None and s.config.nativeUntaggedValues:
                val = val.mantissa if isinstance(val, types.Decimal) and val.exponent == 0 else val.value
            if tag is not None and s.config.nativeTaggedValues:
                val = converters.toNative(val, ParseFragment(s[valueStart:i], s, i))
        return Result((None, val), i)

    if s[i] == "'":
        raise ParseError(s, i, "KDL strings use double-quotes.")

    ident, _ = parseBareIdent(s, i)
    if ident is not Failure and ident.lower() in ("true", "false", "null"):
        raise ParseError(s, i, "KDL keywords are lower-case.")

    # Failed to find a value
    # But if I found a tag, something's up
    if tag is not None:
        raise ParseError(s, i, "Found a tag, but no value following it.")
    return Result.fail(start)


def parseNumber(s: Stream, start: int) -> Result:
    if not isNumberStart(s, start):
        return Result.fail(start)
    res = parseBinaryNumber(s, start)
    if res.valid:
        return res
    res = parseOctalNumber(s, start)
    if res.valid:
        return res
    res = parseHexNumber(s, start)
    if res.valid:
        return res
    res = parseDecimalNumber(s, start)
    if res.valid:
        return res
    raise ParseError(
        s,
        start,
        "Expected a number, but got junk after the initial digit.",
    )


def parseBinaryNumber(s: Stream, start: int) -> Result:
    i = start

    # optional sign
    sign, i = parseSign(s, i)
    if sign is Failure:
        sign = 1

    # prefix
    if not (s[i] == "0" and s[i + 1] == "b"):
        return Result.fail(start)
    i += 2

    # initial digit
    if not isBinaryDigit(s[i]):
        raise ParseError(s, i, "Expected binary digit after 0b, got junk.")

    # following digits/underscores
    end = i + 1
    while isBinaryDigit(s[end]) or s[end] == "_":
        end += 1
    value = int(s[i:end].replace("_", ""), 2) * sign
    return Result(types.Binary(value), end)


def parseOctalNumber(s: Stream, start: int) -> Result:
    i = start

    # optional sign
    sign, i = parseSign(s, i)
    if sign is Failure:
        sign = 1

    # prefix
    if not (s[i] == "0" and s[i + 1] == "o"):
        return Result.fail(start)
    i += 2

    # initial digit
    if not isOctalDigit(s[i]):
        raise ParseError(s, i, "Expected octal digit after 0o, got junk.")

    # following digits/underscores
    end = i + 1
    while isOctalDigit(s[end]) or s[end] == "_":
        end += 1
    value = int(s[i:end].replace("_", ""), 8) * sign
    return Result(types.Octal(value), end)


def parseHexNumber(s: Stream, start: int) -> Result:
    i = start

    # optional sign
    sign, i = parseSign(s, i)
    if sign is Failure:
        sign = 1

    # prefix
    if not (s[i] == "0" and s[i + 1] == "x"):
        return Result.fail(start)
    i += 2

    # initial digit
    if not isHexDigit(s[i]):
        raise ParseError(s, i, "Expected hex digit after 0x, got junk.")

    # following digits/underscores
    end = i + 1
    while isHexDigit(s[end]) or s[end] == "_":
        end += 1
    value = int(s[i:end].replace("_", ""), 16) * sign
    return Result(types.Hex(value), end)


def parseDecimalNumber(s: Stream, start: int) -> Result:
    i = start

    # optional sign
    _, i = parseSign(s, i)

    # integer part
    _, i = parseDigits(s, i)

    if s[i] == ".":
        result, i = parseDigits(s, i + 1)
        if result is Failure:
            raise ParseError(s, i, "Expected digit after decimal point.")

    mantissaChars = s[start:i].replace("_", "")
    mantissa: int | float
    try:
        mantissa = int(mantissaChars, 10)
    except ValueError:
        try:
            mantissa = float(mantissaChars)
        except ValueError as exc:
            raise ParseError(
                s,
                start,
                "Number-like string didn't actually parse as a number.",
            ) from exc

    exponent = 0
    if s[i] in ("e", "E"):
        exponentStart = i + 1
        _, i = parseSign(s, i + 1)
        result, i = parseDigits(s, i)
        if result is Failure:
            raise ParseError(s, i, "Expected number after exponent.")
        exponent = int(s[exponentStart:i].replace("_", ""))

    return Result(types.Decimal(mantissa, exponent), i)


def parseDigits(s: Stream, start: int) -> Result:
    # First digit must be decimal digit
    # Subsequent can be digit or underscore
    if not isDigit(s[start]):
        return Result.fail(start)
    end = start + 1
    while isDigit(s[end]) or s[end] == "_":
        end += 1
    return Result(True, end)


def isNumberStart(s: Stream, start: int) -> bool:
    # all numbers start with an optional sign
    # followed by a digit:
    # either the first digit of the number,
    # or the 0 of the prefix)
    if isDigit(s[start]):
        return True
    if isSign(s[start]) and isDigit(s[start + 1]):
        return True
    return False


def parseSign(s: Stream, start: int) -> Result:
    if s[start] == "+":
        return Result(1, start + 1)
    if s[start] == "-":
        return Result(-1, start + 1)
    return Result.fail(start)


def parseKeyword(s: Stream, start: int) -> Result:
    if s[start : start + 4] == "true" and not isIdentChar(s[start + 4]):
        return Result(types.Bool(True), start + 4)
    if s[start : start + 5] == "false" and not isIdentChar(s[start + 5]):
        return Result(types.Bool(False), start + 5)
    if s[start : start + 4] == "null" and not isIdentChar(s[start + 4]):
        return Result(types.Null(), start + 4)
    return Result.fail(start)


def parseString(s: Stream, start: int) -> Result:
    if s[start] == '"':
        return parseEscapedString(s, start)
    if s[start] == "r" and s[start + 1] in ("#", '"'):
        return parseRawString(s, start)
    return Result.fail(start)


def parseEscapedString(s: Stream, start: int) -> Result:
    if s[start] != '"':
        return Result.fail(start)
    i = start + 1

    rawChars = ""
    while True:
        if s[i] not in ("\\", '"', ""):
            rawChars += s[i]
            i += 1
            continue
        if s[i] == '"':
            break
        if s[i] == "":
            raise ParseError(
                s,
                start,
                "Hit EOF while looking for the end of the string",
            )
        ch, i = parseEscape(s, i)
        if ch is Failure:
            raise ParseError(s, i, "Invalid escape sequence in string")
        rawChars += ch

    return Result(types.String(rawChars), i + 1)


def parseEscape(s: Stream, start: int) -> Result:
    if s[start] != "\\":
        return Result.fail(start)
    ch = s[start + 1]
    if ch == "n":
        return Result("\n", start + 2)
    if ch == "r":
        return Result("\r", start + 2)
    if ch == "t":
        return Result("\t", start + 2)
    if ch == "\\":
        return Result("\\", start + 2)
    if ch == "/":
        return Result("/", start + 2)
    if ch == '"':
        return Result('"', start + 2)
    if ch == "b":
        return Result("\b", start + 2)
    if ch == "f":
        return Result("\f", start + 2)
    if ch == "u":
        if s[start + 2] != "{":
            raise ParseError(
                s,
                start,
                "Unicode escapes must surround their codepoint in {}",
            )
        i = start + 3
        hexStart = i
        while isHexDigit(s[i]):
            i += 1
        hexCount = i - hexStart
        if s[i] != "}":
            raise ParseError(s, hexStart, "Expected } to finish a unicode escape")
        if hexCount < 1:
            raise ParseError(s, hexStart, "Unicode escape doesn't contain a codepoint")
        if hexCount > 6:
            raise ParseError(
                s,
                hexStart,
                "Unicode escapes can contain at most six digits",
            )
        hexValue = int(s[hexStart:i], 16)
        if hexValue > 0x10FFFF:
            raise ParseError(
                s,
                hexStart,
                "Maximum codepoint in a unicode escape is 0x10ffff",
            )
        return Result(chr(hexValue), i + 1)
    raise ParseError(s, start, "Invalid character escape")


def parseRawString(s: Stream, start: int) -> Result:
    if s[start] != "r":
        return Result.fail(start)
    i = start + 1

    # count hashes
    hashCount, i = parseInitialHashes(s, i)

    if s[i] != '"':
        return Result.fail(start)
    i = i + 1

    stringStart = i
    while True:
        while s[i] not in ('"', ""):
            i += 1
        if s[i] == "":
            raise ParseError(
                s,
                start,
                "Hit EOF while looking for the end of the raw string.",
            )
        stringEnd = i
        i += 1
        result, i = parseFinalHashes(s, i, expectedCount=hashCount)
        if result is not Failure:
            return Result(types.RawString(s[stringStart:stringEnd]), i)


def parseInitialHashes(s: Stream, start: int) -> Result:
    i = start
    while s[i] == "#":
        i += 1
    if s[i] == '"':
        return Result(i - start, i)
    return Result.fail(start)


def parseFinalHashes(s: Stream, start: int, expectedCount: int) -> Result:
    i = start
    while s[i] == "#":
        i += 1
    count = i - start
    if count < expectedCount:
        return Result.fail(start)
    if count > expectedCount:
        raise ParseError(
            s,
            start,
            f"Expected {expectedCount} hashes at end of raw string; got {count}.",
        )
    return Result(True, i)


def parseNewline(s: Stream, start: int) -> Result:
    if s[start] == "\x0d" and s[start + 1] == "\x0a":
        return Result(True, start + 2)
    if isNewlineChar(s[start]):
        return Result(True, start + 1)
    return Result.fail(start)


def parseLinespace(s: Stream, start: int) -> Result:
    i = start
    while True:
        nl, i = parseNewline(s, i)
        ws, i = parseWhitespace(s, i)
        sc, i = parseSingleLineComment(s, i)
        if nl is Failure and ws is Failure and sc is Failure:
            break
    if i == start:
        return Result.fail(start)
    return Result(True, i)


def parseNodespace(s: Stream, start: int) -> Result:
    i = start
    while True:
        _, i = parseWhitespace(s, i)
        escline, i = parseEscline(s, i)
        if escline is Failure:
            break
    if i == start:
        return Result.fail(start)
    return Result(True, i)


def parseEscline(s: Stream, start: int) -> Result:
    if s[start] != "\\":
        return Result.fail(start)
    _, i = parseWhitespace(s, start + 1)
    if s[i] == "\n":
        return Result(True, i + 1)
    sl, i = parseSingleLineComment(s, i)
    if sl is not Failure:
        return Result(True, i)
    return Result.fail(start)


def parseWhitespace(s: Stream, start: int) -> Result:
    i = start
    while True:
        sp, i = parseUnicodeSpace(s, i)
        bc, i = parseBlockComment(s, i)
        if sp is Failure and bc is Failure:
            break
    if i == start:
        return Result.fail(start)
    return Result(True, i)


def parseUnicodeSpace(s: Stream, start: int) -> Result:
    if not isWSChar(s[start]):
        return Result.fail(start)
    end = start + 1
    while isWSChar(s[end]):
        end += 1
    return Result(True, end)


def isIdentChar(ch: str) -> bool:
    if not ch:
        return False
    if ch in r'''\/(){}<>;[]=,"''':
        return False
    if isLinespaceChar(ch):
        return False
    cp = ord(ch)
    if cp <= 0x20:
        return False
    if cp > 0x10FFFF:
        return False
    return True


def isKeyword(ident: str) -> bool:
    return ident in ("null", "true", "false")


def isSign(ch: str) -> bool:
    return ch != "" and ch in "+-"


def isDigit(ch: str) -> bool:
    return ch != "" and ch in "0123456789"


def isBinaryDigit(ch: str) -> bool:
    return ch != "" and ch in "01"


def isOctalDigit(ch: str) -> bool:
    return ch != "" and ch in "01234567"


def isHexDigit(ch: str) -> bool:
    return ch != "" and ch in "0123456789abcdefABCDEF"


def isWSChar(ch: str) -> bool:
    if not ch:
        return False
    cp = ord(ch)
    if cp in (0x09, 0x20, 0xA0, 0x1680, 0x202F, 0x205F, 0x3000, 0xFEFF):
        return True
    if 0x2000 <= cp <= 0x200A:
        return True
    return False


def isNewlineChar(ch: str) -> bool:
    if not ch:
        return False
    cp = ord(ch)
    return cp in (0x0A, 0x0D, 0x85, 0x0C, 0x2028, 0x2029)


def isLinespaceChar(ch: str) -> bool:
    if not ch:
        return False
    return isWSChar(ch) or isNewlineChar(ch)


def parseSlashDash(s: Stream, start: int) -> Result:
    if s[start] == "/" and s[start + 1] == "-":
        _, i = parseNodespace(s, start + 2)
        return Result(True, i)
    return Result.fail(start)


def parseSingleLineComment(s: Stream, start: int) -> Result:
    if not (s[start] == "/" and s[start + 1] == "/"):
        return Result.fail(start)
    i = start + 2
    while not isNewlineChar(s[i]) and not s.eof(i):
        i += 1
    _, i = parseNewline(s, i)
    return Result(True, i)


def parseBlockComment(s: Stream, start: int) -> Result:
    if not (s[start] == "/" and s[start + 1] == "*"):
        return Result.fail(start)
    i = start + 2
    while True:
        if s.eof(i):
            raise ParseError(s, start, "Hit EOF while inside a multiline comment")
        if s[i] == "*" and s[i + 1] == "/":
            return Result(True, i + 2)
        if s[i] == "/" and s[i + 1] == "*":
            _, i = parseBlockComment(s, i)
            continue
        i += 1
