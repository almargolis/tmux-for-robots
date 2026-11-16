# 02 — the whole robot, one command, one screen

`robot_up.sh` starts every process of the pretend robot in its own pane of a
single tmux session — the scripted version of "open 10 terminals and paste
commands from the cheat sheet".

```bash
./robot_up.sh          # start everything and show it
#   ... Ctrl-b d to detach, close the laptop, lose wifi, whatever ...
tmux attach -t robot   # look again
./robot_down.sh        # stop everything politely
```

```
┌ 0: broker ───────────────────┬ 1: lidar ────────────────────┐
│[broker] READY listening on   │[lidar] front  212.3 cm |#### │
│[broker] + lidar connected    │[lidar] front  198.0 cm |###  │
├ 2: camera ───────────────────┼ 3: navigator ────────────────┤
│[camera] I see: nothing       │[navigator] path clear        │
│[camera] I see: stop sign     │[navigator] stop sign -- wait │
├ 4: motors ───────────────────┼ 5: teleop ───────────────────┤
│[motors] ^^ speed  66 |====== │[teleop] SPACE = toggle E-STOP│
└──────────────────────────────┴──────────────────────────────┘
```

## Things worth stealing for your own robot

Open [`robot_up.sh`](robot_up.sh) — it is short and commented.

1. **One pane per process.** No log files to hunt through, no tab you forgot
   about. `tmux select-layout tiled` keeps everything visible as panes come
   and go.
2. **Keep the pane open after a crash.** Each pane runs a tiny generated
   wrapper: run the node, print the exit status, then drop into a shell with
   the command already in history. The traceback stays on screen and
   **Up-arrow + Enter** re-runs it. Try:

   ```bash
   CAMERA_ARGS="--crash-after 20" ./robot_up.sh
   ```

3. **Launch order without `sleep`.** The broker starts first; the script
   waits until its port actually answers (`wait_for_port.py`) before starting
   anything that needs it. For ROS you would wait for a topic instead — see
   [`../../smarty`](../../smarty).
4. **Tethered vs headless.** Same script, two behaviours:

   | | tethered (you ran it in a terminal) | headless (boot, cron, systemd) |
   |---|---|---|
   | teleop / interactive tools | started | skipped |
   | attaches to the session | yes | no — runs in the background |
   | output | on screen | on screen **and** `logs/<name>.log` |
   | extra pane | teleop | `console`, tailing every log |

   Force one with `--tethered` / `--headless`.
5. **Polite shutdown.** `robot_down.sh` sends Ctrl-C to each pane, newest
   first, so every node can stop its motors before the session is closed.
6. **Already running?** Running `robot_up.sh` again just re-attaches.

## Start the robot at boot (headless)

Easiest — a crontab line on the robot (`crontab -e`):

```cron
@reboot sleep 20 && /home/pi/tmux-for-robots/examples/02_tmux_robot/robot_up.sh --headless
```

Then, whenever you like: `ssh robot` → `tmux attach -t robot`.

A systemd user service works too (see [`robot.service`](robot.service)) and
is the "grown-up" choice for a robot that must always come up.

## The catch: tmux has to run where the processes run

This script organises processes **on the machine where you run it**.

- Run it on the robot: nodes survive wifi drops and laptop reboots. This is
  what you want.
- Run it on your laptop over SSH: the *views* survive, but the nodes are
  children of your SSH session on the robot and still die when the link
  drops. The panes will faithfully show you the disconnect.

That distinction is the heart of the talk. It is also why the real
`robocars2026/launch` framework runs one session per node **on the robot**.
