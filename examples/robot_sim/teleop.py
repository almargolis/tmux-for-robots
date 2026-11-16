#!/usr/bin/env python3
"""teleop.py -- keyboard E-STOP for the pretend robot. Publishes "estop".

This one needs a human at a keyboard, so the launch scripts only start it
when the robot is TETHERED (you are watching). A HEADLESS robot (started at
boot, nobody attached) skips it.

    python3 teleop.py
    keys:  SPACE = toggle e-stop    q = quit
"""

import sys
import termios
import tty

from minibus import Bus

if not sys.stdin.isatty():
    sys.exit("[teleop] needs a keyboard (a real terminal) -- skipping")

bus = Bus("teleop")
pressed = False
bus.publish("estop", {"pressed": pressed})
print("[teleop] SPACE = toggle E-STOP, q = quit", flush=True)

old = termios.tcgetattr(sys.stdin)
try:
    tty.setcbreak(sys.stdin)
    while True:
        key = sys.stdin.read(1)
        if key == "q":
            break
        if key == " ":
            pressed = not pressed
            bus.publish("estop", {"pressed": pressed})
            print(f"[teleop] E-STOP {'*** PRESSED ***' if pressed else 'released'}", flush=True)
except KeyboardInterrupt:
    pass
finally:
    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old)
    print("\n[teleop] stopped")
