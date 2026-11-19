#!/usr/bin/env python3
"""sensor.py -- a pretend range sensor. One reading per second.

    ./sensor.py

This program has no business reading the keyboard, and it does not: anything
you type in its pane is treated as a corrupted serial byte, and it raises an
exception on the spot. That is the demo. The traceback names the line, the
pane stays open, and starting it again is all it takes -- the *process* died,
not the session.
"""

import os
import select
import sys
import termios
import time
import tty


class SensorError(RuntimeError):
    """What a real driver raises when the hardware surprises it."""


def console_key(fd):
    """The byte waiting on the console, or None. Never waits."""
    if fd is None:
        return None                      # no terminal: nothing to watch
    ready, _, _ = select.select([fd], [], [], 0)
    if not ready:
        return None
    raw = os.read(fd, 1)
    return raw.decode("utf-8", "replace") or None


def read_range(fd):
    """One (pretend) read from the serial port -- and an objection to typing."""
    key = console_key(fd)
    if key is not None:
        raise SensorError(
            f"got {key!r} while reading /dev/ttyUSB0: "
            "this driver has no interactive input"
        )


def main():
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd) if sys.stdin.isatty() else None
    if saved is not None:
        tty.setcbreak(fd)                 # one keypress, no Enter needed
    watch = fd if saved is not None else None   # headless: nothing to watch

    print("[sensor] 1 Hz. Press any key to make this crash.", flush=True)
    n = 0
    try:
        while True:
            n += 1
            read_range(watch)
            print(f"sensor reading {n:3d}   {time.strftime('%H:%M:%S')}", flush=True)
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[sensor] stopped", flush=True)
    finally:
        if saved is not None:
            termios.tcsetattr(fd, termios.TCSADRAIN, saved)


if __name__ == "__main__":
    main()
