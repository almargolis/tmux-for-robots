#!/usr/bin/env python3
"""wait_for_port.py -- block until something is listening on a TCP port.

A better "sleep 2". Launch scripts use it so the nodes start only after
the broker is actually ready -- no guessing how long that takes.

    python3 wait_for_port.py 7777                 # localhost, 30 s timeout
    python3 wait_for_port.py 7777 --host mockbot --timeout 60

Exit status 0 when the port is open, 1 on timeout.
"""

import argparse
import socket
import sys
import time

p = argparse.ArgumentParser()
p.add_argument("port", type=int)
p.add_argument("--host", default="127.0.0.1")
p.add_argument("--timeout", type=float, default=30)
args = p.parse_args()

deadline = time.time() + args.timeout
while time.time() < deadline:
    try:
        socket.create_connection((args.host, args.port), timeout=1).close()
        sys.exit(0)
    except OSError:
        time.sleep(0.2)
print(f"timed out waiting for {args.host}:{args.port}", file=sys.stderr)
sys.exit(1)
