#!/usr/bin/env python3
"""lidar.py -- pretend distance sensor. Publishes topic "scan" at 5 Hz.

It also contains a (very) tiny world: the robot drives toward a wall at
whatever speed the motors report, and when the robot turns, a new wall
appears somewhere ahead.

    python3 lidar.py
"""

import random
import time

from minibus import Bus

bus = Bus("lidar")
bus.subscribe("motors")

distance = 300.0          # cm to the wall ahead
speed, turning = 0.0, False
print("[lidar] publishing 'scan' at 5 Hz", flush=True)

try:
    while True:
        t_end = time.time() + 0.2
        while (msg := bus.recv(timeout=max(0.0, t_end - time.time()))) is not None:
            _, data = msg
            speed, turning = data["speed"], data["turn"] != 0
        if turning:
            distance = random.uniform(150, 400)
        else:
            distance = max(5.0, distance - speed * 0.2)
        reading = round(distance + random.uniform(-2, 2), 1)
        bus.publish("scan", {"front_cm": reading})
        bar = "#" * int(min(reading, 400) / 10)
        print(f"[lidar] front {reading:6.1f} cm |{bar:<40}|", flush=True)
except KeyboardInterrupt:
    print("\n[lidar] stopped")
