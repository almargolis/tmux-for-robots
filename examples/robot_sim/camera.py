#!/usr/bin/env python3
"""camera.py -- pretend camera + vision. Publishes topic "vision" every 2 s.

    python3 camera.py                  # runs forever
    python3 camera.py --crash-after 30 # "USB cable falls out" after 30 s

The --crash option is for the demo: it shows why you want a launcher that
keeps the window open after a process dies, so you can read the traceback.
"""

import argparse
import random
import time

from minibus import Bus

parser = argparse.ArgumentParser()
parser.add_argument("--crash-after", type=float, default=0, metavar="SECONDS",
                    help="simulate a camera failure after this many seconds")
args = parser.parse_args()

bus = Bus("camera")
started = time.time()
things = ["nothing"] * 6 + ["cat", "chair leg", "stop sign"]
print("[camera] publishing 'vision' every 2 s", flush=True)


def grab_frame():
    if args.crash_after and time.time() - started > args.crash_after:
        raise OSError("/dev/video0: No such device (did the USB cable fall out?)")
    return random.choice(things)


try:
    while True:
        seen = grab_frame()
        bus.publish("vision", {"seen": seen})
        print(f"[camera] {time.strftime('%H:%M:%S')} I see: {seen}", flush=True)
        time.sleep(2)
except KeyboardInterrupt:
    print("\n[camera] stopped")
