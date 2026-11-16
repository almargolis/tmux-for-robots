#!/usr/bin/env python3
"""motors.py -- pretend motor driver. Obeys "cmd", reports on "motors".

Has a safety WATCHDOG, like any real motor controller should: if no command
arrives for 1 second (navigator crashed, wifi dropped, ...) it stops.
Try killing navigator.py while this runs.

    python3 motors.py
"""

import time

from minibus import Bus

bus = Bus("motors")
bus.subscribe("cmd")

speed, turn, last_cmd = 0, 0, time.time()
watchdog_tripped = False
print("[motors] ready (watchdog: 1.0 s)", flush=True)

try:
    while True:
        msg = bus.recv(timeout=0.2)
        if msg is not None:
            _, data = msg
            speed, turn, last_cmd = data["speed"], data["turn"], time.time()
            if watchdog_tripped:
                print("[motors] commands are back -- watchdog cleared", flush=True)
                watchdog_tripped = False
        elif time.time() - last_cmd > 1.0 and not watchdog_tripped:
            speed, turn, watchdog_tripped = 0, 0, True
            print("[motors] WATCHDOG: no commands for 1 s -- MOTORS STOPPED", flush=True)

        bus.publish("motors", {"speed": speed, "turn": turn})
        if msg is not None:
            arrow = "<<" if turn < 0 else ">>" if turn > 0 else "^^"
            gauge = "=" * (speed // 5)
            print(f"[motors] {arrow} speed {speed:3d} |{gauge:<20}|", flush=True)
except KeyboardInterrupt:
    print("\n[motors] stopped")
