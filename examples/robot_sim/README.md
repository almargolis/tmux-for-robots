# robot_sim — a pretend robot with no dependencies

Five tiny Python programs that talk to each other over a message bus, so you
can practise process organisation without installing ROS, Docker, or anything
else. Python 3.8+ and the standard library are enough.

```
                    ┌──────────────┐
   keyboard ───────▶│  teleop.py   │── estop ──┐
                    └──────────────┘           │
                                               ▼
  ┌───────────┐  scan   ┌──────────────┐   cmd   ┌────────────┐
  │ lidar.py  │────────▶│ navigator.py │────────▶│ motors.py  │
  └───────────┘         └──────────────┘         └────────────┘
        ▲                      ▲                       │
        │                      │ vision                │ motors
        │               ┌──────────────┐               │
        └───────────────│  camera.py   │◀──────────────┘
                        └──────────────┘
                  all messages go through broker.py
```

`broker.py` is the hub. Like a real ROS graph, **it has to be running before
anything else starts** — the other programs exit with a clear error if they
cannot reach it. That is deliberate: it gives the launch scripts something
real to order.

## Run it by hand (one terminal per process)

```bash
cd examples/robot_sim

python3 broker.py          # terminal 1 — leave this running
python3 lidar.py           # terminal 2
python3 camera.py          # terminal 3
python3 navigator.py       # terminal 4
python3 motors.py          # terminal 5
python3 teleop.py          # terminal 6 — SPACE = e-stop, q = quit
```

Then try these:

```bash
python3 echo.py cmd        # like `ros2 topic echo /cmd`
python3 camera.py --crash-after 10   # "the USB cable falls out" after 10 s
```

Kill `navigator.py` while the others run. Within one second `motors.py` prints
`WATCHDOG: no commands for 1 s -- MOTORS STOPPED`. A separate, supervised
process is what makes that kind of safety possible.

## The topics

| Topic | Publisher | Subscribers | Payload |
|---|---|---|---|
| `scan` | `lidar.py` | `navigator.py` | `{"front_cm": 212.3}` |
| `vision` | `camera.py` | `navigator.py` | `{"seen": "stop sign"}` |
| `estop` | `teleop.py` | `navigator.py` | `{"pressed": false}` |
| `cmd` | `navigator.py` | `motors.py` | `{"speed": 60, "turn": 0, "reason": "..."}` |
| `motors` | `motors.py` | `lidar.py` | `{"speed": 60, "turn": 0}` |

## Files

| File | What it is |
|---|---|
| `minibus.py` | The whole pub/sub library: one socket, newline-delimited JSON. |
| `broker.py` | Routes messages between nodes; prints traffic every 5 s. |
| `lidar.py` | Invented distance sensor; publishes `scan` at 5 Hz. |
| `camera.py` | Invented camera; optionally crashes, for demoing failure. |
| `navigator.py` | Tiny rule-based brain. |
| `motors.py` | Motor driver with a 1-second command watchdog. |
| `teleop.py` | Keyboard e-stop; needs a real terminal, so it is skipped headless. |
| `wait_for_port.py` | `sleep` with feedback: block until a TCP port answers. |
| `echo.py` | Print one topic, like `ros2 topic echo`. |

Everything is intentionally small. Read `minibus.py` once and you have seen
the entire "framework".
