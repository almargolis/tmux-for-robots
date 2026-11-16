# smarty — the cheat sheet becomes one command

[Smarty.md](https://docs.google.com/document/d/1Sg-Xfg9Mm2aaPD8RT6Pu--qHWCRthnQeKTDLjL73_3Q/edit?usp=sharing)
is how one member starts their robot: open ten terminals, `ssh` to the right
host in each, and paste a command from the document. It works, and it is a
perfect summary of the problem this talk is about.

This directory turns that document into a tmux session with a **profile**:

```bash
cp smarty.conf.example smarty.conf     # then edit hosts, paths, commands
./smarty.sh mapping --dry-run          # see the plan, start nothing
./smarty.sh mapping                    # mapping: SLAM + map saver
./smarty.sh navigation                 # navigation: localisation + Nav2
./smarty.sh status                     # what is running?
./smarty.sh stop                       # Ctrl-C each pane, then close
```

```
smarty: 4 windows
  0: robot    base · lidar                 (ssh mockbot)
  1: sensors  camera · talker              (ssh marvin, ssh atlas)
  2: slam     display · toolbox · turtlebot · rviz
  3: drive    teleop · map-saver (ready)
```

## Before and after

**Before** — ten windows, ten pastes, no record of the order:

```
ssh mockbot → ros2 launch create_bringup create_2.launch
ssh mockbot → ros2 launch ldlidar_stl_ros2 ld06.launch.py
ssh marvin  → v4l2-ctl -d /dev/video0 -p 5
ssh marvin  → ros2 run v4l2_camera v4l2_camera_node
ssh atlas   → ros2 run py_pubsub talker
...
ros2 launch slam_toolbox online_async_launch.py
ros2 launch nav2_bringup rviz_launch.py
ros2 run teleop_twist_keyboard teleop_twist_keyboard
ros2 run nav2_map_server map_saver_cli -f ~/maps/map ...
```

**After** — one command, the same commands, in a fixed order, with checks:

```bash
./smarty.sh mapping
```

Nothing about the ROS commands changed. What changed is that the launch
sequence now lives in a file you can review, diff, fix once, and hand to the
next person.

## What the script adds

| Before | After |
|---|---|
| You remember the order | Windows and panes are created in order |
| `sleep 10` and hope | `wait_topic` checks that `/scan` and `/image_raw` actually exist |
| A crash closes the window | The pane stays open with the traceback and a shell |
| Ten scrollback buffers | `./smarty.sh status` lists what should be running |
| "Which terminal was the map saver in?" | It is the `map-saver` pane, with the command in history |
| Editing the Google Doc | Editing `smarty.conf` |

### The map-saver pane

The last pane is not started. It is a shell whose previous command is the
`map_saver_cli` line. Drive the map, look at it in rviz, and when it is good:

1. `Ctrl-b` then the pane number for `drive`/`map-saver`
2. press **Up-arrow**, then **Enter**

That is deliberately the same interaction as the cheat sheet — paste, press
Enter — but the command is already correct and in the right directory.

## Profiles

| Profile | Starts | For |
|---|---|---|
| `mapping` | base, lidar, camera, talker, display, slam_toolbox, turtlebot SLAM, rviz, teleop, map-saver | building a new map |
| `navigation` | base, lidar, camera, talker, display, localisation (with `$MAP_FILE`), Nav2, rviz, teleop | driving on an existing map |

`mapping` is the default. Add a profile by adding a branch in the `if [ "$PROFILE" = mapping ]`
block — the surrounding machinery does not change.

## Configuration

Everything site-specific is in `smarty.conf` (plain shell, copied from
`smarty.conf.example`):

```bash
ROBOT_HOST="mockbot"     # Pi 5: Roomba base + lidar
CAMERA_HOST="marvin"     # camera Pi
ATLAS_HOST="atlas"       # ultrasonic / misc Pi

ROS_SETUP='source /opt/ros/jazzy/setup.bash && source ~/ros2_ws/install/setup.bash'
LOCAL_ROS_SETUP="$ROS_SETUP"
LOCAL_WS="$HOME/ros2_ws"

MAP_FILE="$HOME/ros2_ws/src/maps/map.yaml"
MAP_SAVE="$HOME/ros2_ws/src/maps/map"

CMD_BASE='ros2 launch create_bringup create_2.launch'
CMD_LIDAR='ros2 launch ldlidar_stl_ros2 ld06.launch.py'
...
```

The defaults are taken from Smarty.md and are **examples, not a tested
configuration for your robot**. They will need the package names, topics, and
paths your robot actually uses. `--dry-run` prints the whole plan without
touching tmux, which is the fastest way to check the edit.

Override at run time without editing the file:

```bash
ROBOT_HOST=myrobot MAP_FILE=~/maps/lab.yaml ./smarty.sh navigation
```

## Remote panes: why there is a base64 blob

Each remote pane runs roughly:

```bash
ssh -t mockbot 'echo <base64> | base64 -d | bash; exec bash -l'
```

The base64 is the ROS setup plus the command plus a message on exit. `ssh`
joins its arguments with spaces and lets the *remote* shell re-parse them, so a
multi-line script with quotes is a classic quoting trap. Base64 sidesteps the
whole problem: the remote shell decodes a single opaque token.

After the command exits, `exec bash -l` leaves you on the robot with a login
shell. The tmux pane (and the message) stays open.

## The catch, again

This script organises **views**. Look at where each command runs:

| Pane | Process runs on | Survives wifi drop? |
|---|---|---|
| `robot/base`, `robot/lidar` | `mockbot` (via ssh) | **no** — unless the robot runs its own tmux/systemd |
| `sensors/*` | `marvin`, `atlas` (via ssh) | **no** — same reason |
| `slam/*`, `nav/*`, `drive/*` | your workstation | yes — tmux owns them locally |

So `smarty.sh` on the laptop is a huge usability win and **not** a fix for the
wifi-drop problem. To fix that:

- run the on-robot parts in a tmux session **on the robot** (or under systemd),
  and use `smarty.sh` only for the workstation-side processes; or
- keep `smarty.sh` as the single entry point, but change the `robot` and
  `sensors` panes to `ssh robot tmux attach -t robot-nodes` — the remote tmux
  server is then the parent, and the ssh client is disposable.

The second option is the pattern from the talk: views on the laptop, processes
on the robot.

## If you prefer herdr

The same configuration maps cleanly onto herdr. A reasonable shape is one
workspace per profile and one pane per command; the `smarty.conf` values can be
reused as-is:

```bash
# one workspace, then one pane per host/stage
herdr workspace create --label smarty-mapping --cwd "$LOCAL_WS"
herdr pane split w1:p1 --direction right --cwd "$LOCAL_WS"
herdr pane run w1:p2 "ssh -t $ROBOT_HOST '...'"
```

What herdr adds is the sidebar: an agent can see the panes, read them with
`herdr pane read`, and answer "which node is stuck?" without you describing ten
terminal windows. See [`../examples/herdr/`](../examples/herdr/) for a complete
worked example.

## Files

| File | Purpose |
|---|---|
| `smarty.sh` | profiles, windows, panes, topic waits, status/stop |
| `smarty.conf.example` | hosts, ROS setup, maps, commands — copy to `smarty.conf` |
| `smarty.conf` | your local edits (git-ignored) |
