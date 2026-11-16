#!/usr/bin/env python3
"""broker.py -- the message broker for the pretend robot. START THIS FIRST.

Every other node connects here to publish and subscribe to topics.
Prints a READY line once it is listening (launch scripts wait for that),
then a short traffic report every few seconds so you can see it is alive.

    python3 broker.py
"""

import asyncio
import json
import time
from collections import Counter, defaultdict

from minibus import HOST, PORT

subscribers = defaultdict(set)  # topic -> set of writers
traffic = Counter()             # topic -> messages since last report
names = {}                      # writer -> node name


async def handle(reader, writer):
    names[writer] = "?"
    try:
        while line := await reader.readline():
            msg = json.loads(line)
            op = msg.get("op")
            if op == "hello":
                names[writer] = msg["name"]
                print(f"[broker] + {msg['name']} connected", flush=True)
            elif op == "sub":
                subscribers[msg["topic"]].add(writer)
            elif op == "pub":
                traffic[msg["topic"]] += 1
                out = (json.dumps({"topic": msg["topic"], "data": msg["data"]}) + "\n").encode()
                for w in list(subscribers[msg["topic"]]):
                    try:
                        w.write(out)
                    except Exception:
                        subscribers[msg["topic"]].discard(w)
    except (ConnectionError, ValueError):
        pass
    finally:
        name = names.pop(writer, "?")
        if name != "?":  # unnamed = a port probe such as wait_for_port.py
            print(f"[broker] - {name} disconnected", flush=True)
        for subs in subscribers.values():
            subs.discard(writer)
        writer.close()


async def report():
    while True:
        await asyncio.sleep(5)
        parts = ", ".join(f"{t}:{n}" for t, n in sorted(traffic.items())) or "no traffic"
        print(f"[broker] {time.strftime('%H:%M:%S')} {len(names)} nodes | msgs/5s {parts}", flush=True)
        traffic.clear()


async def main():
    server = await asyncio.start_server(handle, HOST, PORT)
    print(f"[broker] READY listening on {HOST}:{PORT}", flush=True)
    async with server:
        await asyncio.gather(server.serve_forever(), report())


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[broker] stopped")
