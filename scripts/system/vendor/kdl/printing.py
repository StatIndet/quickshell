from dataclasses import dataclass


@dataclass
class PrintConfig:
    indent: str = "\t"
    semicolons: bool = False
    printNullArgs: bool = True
    printNullProps: bool = True
    respectRadix: bool = True
    respectStringType: bool = True
    exponent: str = "e"
    sortProperties: bool = False


defaults = PrintConfig()
