#!/usr/bin/env python3
"""echo.py -- print every message on a topic (like `ros2 topic echo`).

    python3 echo.py cmd
    python3 echo.py scan
"""

import sys

from minibus import Bus

if len(sys.argv) != 2:
    sys.exit("usage: python3 echo.py TOPIC     (topics: scan vision cmd motors estop)")

topic = sys.argv[1]
bus = Bus(f"echo-{topic}")
bus.subscribe(topic)
try:
    while True:
        print(bus.recv())
except KeyboardInterrupt:
    pass
