# Python

## Options and environment variables

- `-O` tells CPython to disable assertions.
- [`PYTHONDEVMODE`] tells CPython to enable some special checks
- [`PYTHONWARNINGS`] enables different warning controls.

[`PYTHONDEVMODE`]: https://docs.python.org/3/library/devmode.html
[`PYTHONWARNINGS`]: https://docs.python.org/3/using/cmdline.html#envvar-PYTHONWARNINGS

## Snippets

### Script template

```py
#!/usr/bin/env python3

"""Description goes here"""

from argparse import ArgumentParser
from pathlib import Path
from sys import exit, stderr


def eprint(*args, **kwargs):
    print(*args, file=stderr, **kwargs)


def die(msg: str, /) -> None:
    eprint(msg)
    exit(1)


def go(paths: list[Path], /, *, flag: bool = False):
    pass


parser = ArgumentParser(description=__doc__)
parser.add_argument("--flag", action="store_true")
parser.add_argument("paths", nargs="+", type=Path)
args = parser.parse_args()
go(args.paths, flag=args.flag)
```

### Using `Enum` with `argparse`

```python
@unique
class Format(str, Enum):
    """Export format"""

    TEXT = "text"
    CSV = "csv"

    def __str__(self) -> str:
        """For inclusion in --help"""
        return self.value

parser.add_argument('--format', type=Format, help=Format.__doc__, choices=list(Format), default=Format.TEXT)
```
