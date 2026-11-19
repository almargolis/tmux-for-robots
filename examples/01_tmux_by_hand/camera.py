#!/usr/bin/env python3
"""camera.py -- a pretend camera. One frame every two seconds.

    ./camera.py

Same trick as sensor.py: press any key in this pane and the driver treats it
as a corrupt byte from /dev/video0 and raises. A camera that dies in a pane
leaves its traceback on screen; a camera that dies in a plain terminal takes
the window with it.
"""

import os
import select
import sys
import termios
import time
import tty


class CameraError(RuntimeError):
    """What a real driver raises when the device misbehaves."""


def console_key(fd):
    """The byte waiting on the console, or None. Never waits."""
    if fd is None:
        return None                      # no terminal: nothing to watch
    ready, _, _ = select.select([fd], [], [], 0)
    if not ready:
        return None
    raw = os.read(fd, 1)
    return raw.decode("utf-8", "replace") or None


def grab_frame(fd):
    """Wait for one frame -- and object to bytes arriving on a console."""
    key = console_key(fd)
    if key is not None:
        raise CameraError(f"/dev/video0 returned {key!r}, which is not a frame")


def main():
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd) if sys.stdin.isatty() else None
    if saved is not None:
        tty.setcbreak(fd)                 # one keypress, no Enter needed
    watch = fd if saved is not None else None   # headless: nothing to watch

    print("[camera] 0.5 Hz. Press any key to make this crash.", flush=True)
    n = 0
    try:
        while True:
            n += 1
            grab_frame(watch)
            print(f"camera frame   {n:3d}   {time.strftime('%H:%M:%S')}", flush=True)
            time.sleep(2)
    except KeyboardInterrupt:
        print("\n[camera] stopped", flush=True)
    finally:
        if saved is not None:
            termios.tcsetattr(fd, termios.TCSADRAIN, saved)


if __name__ == "__main__":
    main()
