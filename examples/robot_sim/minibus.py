"""minibus -- a tiny publish/subscribe message bus for the pretend robot.

Think of it as "ROS topics with training wheels": one broker process
(broker.py) and any number of nodes that publish and subscribe to named
topics. Pure Python standard library -- nothing to install.

    from minibus import Bus
    bus = Bus("navigator")              # connects to the broker
    bus.subscribe("scan")
    bus.publish("cmd", {"speed": 20})
    msg = bus.recv(timeout=1.0)         # -> ("scan", {...}) or None

Like a real robot, the broker MUST be running before any node starts.
If it is not, nodes print a friendly error and exit -- which is exactly
the "launch order" problem the launch scripts in this repo solve.

Environment:
    MINIBUS_HOST  (default 127.0.0.1)
    MINIBUS_PORT  (default 7777)
"""

import json
import os
import queue
import socket
import sys
import threading

HOST = os.environ.get("MINIBUS_HOST", "127.0.0.1")
PORT = int(os.environ.get("MINIBUS_PORT", "7777"))


class Bus:
    def __init__(self, name):
        self.name = name
        self._inbox = queue.Queue()
        try:
            self._sock = socket.create_connection((HOST, PORT), timeout=3)
        except OSError:
            print(
                f"[{name}] ERROR: cannot reach the broker at {HOST}:{PORT}.\n"
                f"[{name}]        Is broker.py running? It has to start FIRST.",
                file=sys.stderr,
            )
            sys.exit(1)
        self._sock.settimeout(None)
        self._wfile = self._sock.makefile("w", encoding="utf-8")
        self._lock = threading.Lock()
        self._send({"op": "hello", "name": name})
        threading.Thread(target=self._reader, daemon=True).start()

    # -- public API ---------------------------------------------------
    def publish(self, topic, data):
        self._send({"op": "pub", "topic": topic, "data": data})

    def subscribe(self, topic):
        self._send({"op": "sub", "topic": topic})

    def recv(self, timeout=None):
        """Return (topic, data), or None if nothing arrived in time."""
        try:
            item = self._inbox.get(timeout=timeout)
        except queue.Empty:
            return None
        if item is None:  # reader thread saw the broker go away
            print(f"[{self.name}] ERROR: lost connection to the broker.", file=sys.stderr)
            sys.exit(1)
        return item

    # -- internals ----------------------------------------------------
    def _send(self, obj):
        try:
            with self._lock:
                self._wfile.write(json.dumps(obj) + "\n")
                self._wfile.flush()
        except OSError:
            print(f"[{self.name}] ERROR: lost connection to the broker.", file=sys.stderr)
            sys.exit(1)

    def _reader(self):
        try:
            for line in self._sock.makefile("r", encoding="utf-8"):
                msg = json.loads(line)
                self._inbox.put((msg["topic"], msg["data"]))
        except (OSError, ValueError):
            pass
        self._inbox.put(None)
