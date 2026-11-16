#!/usr/bin/env python3
"""navigator.py -- the "brain". Reads "scan", "vision", "estop"; publishes "cmd".

Rules (deliberately simple):
    * e-stop pressed          -> stop
    * stop sign seen          -> stop for 3 seconds
    * wall closer than 60 cm  -> turn
    * otherwise               -> drive, faster when the way is clear

    python3 navigator.py
"""

import time

from minibus import Bus

bus = Bus("navigator")
for topic in ("scan", "vision", "estop"):
    bus.subscribe(topic)

front_cm, estop, stop_until = 999.0, False, 0.0
last_reason = None
print("[navigator] thinking at 5 Hz", flush=True)

try:
    while True:
        t_end = time.time() + 0.2
        while (msg := bus.recv(timeout=max(0.0, t_end - time.time()))) is not None:
            topic, data = msg
            if topic == "scan":
                front_cm = data["front_cm"]
            elif topic == "estop":
                estop = data["pressed"]
            elif topic == "vision" and data["seen"] == "stop sign":
                stop_until = time.time() + 3

        if estop:
            speed, turn, reason = 0, 0, "E-STOP pressed"
        elif time.time() < stop_until:
            speed, turn, reason = 0, 0, "stop sign -- waiting"
        elif front_cm < 60:
            speed, turn, reason = 10, 1, f"wall at {front_cm:.0f} cm -- turning"
        else:
            speed, turn, reason = min(100, int(front_cm / 3)), 0, "path clear -- driving"

        bus.publish("cmd", {"speed": speed, "turn": turn, "reason": reason})
        if reason.split(" ")[0] != (last_reason or "").split(" ")[0]:
            print(f"[navigator] {time.strftime('%H:%M:%S')} {reason}", flush=True)
            last_reason = reason
except KeyboardInterrupt:
    print("\n[navigator] stopped")
