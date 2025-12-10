# gdb

## Useful commands

- `info args`/`functions`/`locals`/`variables`/`register`
- `layout asm`
- [`record`](https://sourceware.org/gdb/current/onlinedocs/gdb.html/Process-Record-and-Replay.html)

## Snippets

### Backtrace on exit

```sh
catch syscall exit_group
run
bt
```

## Using `gdb` non-interactively

### Via the command line

```sh
gdb prog -ex run -ex bt -ex q
```

### Via Python scripting

See more below.

```py
#!/usr/bin/gdb -x

# trick type checkers
if globals().get("gdb") is None:
    from typing import Any
    gdb: Any = globals()["gdb"]

def go():
    gdb.execute("file prog")
    gdb.execute("core prog.core")
    gdb.execute("bt")

try:
    go()
except Exception as e:
    print(e)
finally:
    gdb.execute("quit")
```

## Python API

### Breakpoints

```py
from gdb import Breakpoint

class MyBreakpoint(Breakpoint):
  def stop(self):
      print("here")

breakpoint = MyBreakpoint("function_name")
breakpoint.enabled = True
```

### Events

```py
def stop_handler(event):
    print("stopped")

gdb.events.stop.connect(stop_handler)
```

## See also

- [rr](https://rr-project.org/)
