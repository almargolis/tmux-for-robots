# 03 — one tiny script per process (the launch directory)

This is the pattern from the real robot in `robocars2026/launch/`: a directory
that holds the robot's config plus one small shell script per process. It is
what you use when "one pane per process" is not enough — when each process
should have its own session, its own place to crash, and its own start/stop
lifecycle.

```bash
./launch_all          # broker, lidar, camera, navigator, motors, in order
./status              # what is running? what exited?
./stop_all            # Ctrl-C newest-first, then close the sessions
```

Every node gets its own session, so `tmux ls` reads like a process list:

```console
$ tmux ls
broker:    1 windows (created ...)
camera:    1 windows (created ...)
lidar:     1 windows (created ...)
motors:    1 windows (created ...)
navigator: 1 windows (created ...)
```

| Script | Node | Session |
|---|---|---|
| `launch_broker` | `broker.py` | `broker` |
| `launch_lidar` | `lidar.py` | `lidar` |
| `launch_camera` | `camera.py` | `camera` |
| `launch_navigator` | `navigator.py` | `navigator` |
| `launch_motors` | `motors.py` | `motors` |
| `launch_teleop` | `teleop.py` | `teleop` (foreground by default) |

## How a launch script works

Each one is six lines:

```bash
SESSION=camera
NODE_CMD="python3 camera.py ${CAMERA_ARGS:-}"
NEEDS_PORT=${MINIBUS_PORT:-7777}
source "$(dirname "${BASH_SOURCE[0]}")/_launch_common.sh"
```

`_launch_common.sh` does the work:

- `cd`s to the right directory and activates a virtualenv (edit that line for
  your robot);
- waits for `NEEDS_PORT` before starting, so **launch order is a dependency,
  not a `sleep 2`**;
- starts the node in a detached session, inside a wrapper that keeps the pane
  open and the command in history if it crashes;
- accepts `-f` (foreground, Ctrl-C to stop) or `-d` (detached).

`./launch_all` is just the list in the right order. `./stop_all` reverses it
and sends Ctrl-C first, so motors stop before the broker disappears.

## Try the failure cases

```bash
CAMERA_ARGS="--crash-after 5" ./launch_camera   # dies after 5 s
./status                                        # camera: EXITED
tmux attach -t camera                           # read the traceback
# press Up-arrow, Enter to run it again
```

Kill the broker while everything runs:

```bash
tmux kill-session -t broker
./status
```

The nodes print a clear error and exit; their sessions stay open so you can
see why.

## GNU screen instead of tmux

The same scripts work with screen:

```bash
MUX=screen ./launch_all
MUX=screen ./status
MUX=screen ./stop_all
```

That is deliberate: the *organisation* is the lesson, not the brand of
multiplexer. The real robot uses screen today; this repo's default is tmux
because panes and `send-keys` are easier to script.

Under screen, `status` reports the session rather than the child process, so a
node that crashed still looks "running" until you attach and see the traceback.
tmux can tell the difference because it exposes `pane_pid`; screen's process
model does not, as cheaply.

## When to use this vs. one session with panes

| Use one session with panes (example 02) | Use one session per process (this example) |
|---|---|
| You want to *watch* everything at once | You want independent start/stop/restart |
| A single robot, started as a unit | Services with different lifetimes |
| Teaching, debugging, demos | Boot-time startup, systemd/cron |
| Layout is the interface | Process lifecycle is the interface |

Both keep running when your terminal goes away. Pick the one that matches how
you think about the machine.
