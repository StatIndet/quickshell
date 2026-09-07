import argparse
import sys

from . import parsefuncs, parsing, printing


def cli() -> None:
    cliParser = argparse.ArgumentParser(
        description="KDL parser/printer, letting you easily reformat KDL files into a canonical representation.",
    )
    cliParser.add_argument(
        "infile",
        nargs="?",
        type=argparse.FileType("r", encoding="utf-8"),
        default=sys.stdin,
    )
    cliParser.add_argument(
        "outfile",
        nargs="?",
        type=argparse.FileType("w", encoding="utf-8"),
        default=sys.stdout,
    )
    cliParser.add_argument(
        "--indent",
        dest="indent",
        type=int,
        action="store",
        default="-1",
        help="How many spaces for each level of indent. -1 indicates to indent with tabs.",
    )
    cliParser.add_argument(
        "--semicolons",
        dest="semicolons",
        action="store_true",
        default=False,
        help="Whether to end nodes with semicolons or not.",
    )
    cliParser.add_argument(
        "--radix",
        dest="respectRadix",
        action="store_true",
        help="Output numeric values in the radix used by the input. (0x1a outputs as 0x1a)",
    )
    cliParser.add_argument(
        "--no-radix",
        dest="respectRadix",
        action="store_false",
        help="Convert all numeric arguments to decimal. (0x1a outputs as 26)",
    )
    cliParser.add_argument(
        "--raw-strings",
        dest="respectStringType",
        action="store_true",
        help="Output string values in the string type used by the input.",
    )
    cliParser.add_argument(
        "--no-raw-strings",
        dest="respectStringType",
        action="store_false",
        help="Convert all string arguments into plain strings.",
    )
    cliParser.add_argument(
        "--exponent",
        dest="exponent",
        type=expFromString,
        action="store",
        default="e",
        help="What character to use ('e' or 'E') for indicating exponents on scinot numbers.",
    )
    cliParser.set_defaults(respectRadix=True, respectStringType=True)
    options = cliParser.parse_args()
    parseConfig = parsing.ParseConfig(
        nativeUntaggedValues=False,
        nativeTaggedValues=False,
    )
    printConfig = printing.PrintConfig(
        indent=" " * options.indent if options.indent >= 0 else "\t",
        semicolons=options.semicolons,
        respectRadix=options.respectRadix,
        respectStringType=options.respectStringType,
        exponent=options.exponent,
    )

    with options.infile as fh:
        doc = parsefuncs.parse(fh.read(), parseConfig)
    with options.outfile as fh:
        fh.write(doc.print(printConfig))


def expFromString(s: str) -> str:
    if s in ("e", "E"):
        return s
    msg = f"Expected 'e' or 'E' for an exponent; got '{s}'"
    raise argparse.ArgumentTypeError(msg)
