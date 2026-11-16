# Two-minute agent demo (herdr)

A live runbook for the last segment. The goal is not "look, an AI drives a
robot." The goal is: **the layout is an API, so an agent can look at the same
panes you are looking at.**

If anything misbehaves, drop the agent and stay on the CLI. The slide already
shows `herdr pane list` / `pane read`, which is the same point without the
theatre.

## Before the talk

```bash
cd examples/herdr
./robot_herdr.sh
herdr                      # leave the TUI on the robot-sim workspace
```

Check that an agent you actually have installed is detected by herdr
(`claude`, `opencode`, `codex`, …):

```bash
herdr agent --help | head -20
```

The `--kind` values are listed by `herdr agent start --help`. Substitute your
own; the demo uses `claude` as the example.

## The demo

### 0:00 — make one node unhealthy

In the TUI, click the **camera** pane and run:

```
python3 camera.py --crash-after 2
```

or from another terminal, using the saved pane ids:

```bash
source "${TMPDIR:-/tmp}/herdr-robot-sim/panes.env"
herdr pane run "$CAMERA_PANE" 'python3 camera.py --crash-after 2'
```

The camera exits. Say: *"On a real robot this is the USB cable, the OOM killer,
or a package that didn't build. Normally this is the window you closed by
accident."*

### 0:20 — start an agent in the spare pane

```bash
source "${TMPDIR:-/tmp}/herdr-robot-sim/panes.env"
herdr agent start reviewer --kind claude --pane "$AGENT_PANE"
```

The `agent-shell` pane becomes an agent pane; the sidebar should show it.

### 0:30 — give it a read-only job

```bash
herdr agent prompt reviewer \
  "You are inspecting a pretend robot laid out in herdr panes.
   Read the broker, lidar, camera, navigator, and motors panes.
   Tell me which node is unhealthy and quote the line that proves it.
   Do not restart, stop, or edit anything." --wait
```

`--wait` blocks until the agent reaches idle/done/blocked, so you are not
guessing when to look. If it takes longer than you want on stage, skip the
`--wait` and show the sidebar instead.

### 1:00 — show that you can watch it work

```bash
herdr agent list
herdr agent read reviewer --lines 25
```

Then click the agent pane in the TUI so the audience sees the same thing you
do. The agent has been reading panes with the same `herdr pane read` you used
in the previous slide.

### 1:30 — the point

> "I did not describe ten terminal windows to it. It read the panes.
> That works because the multiplexer is a server with an API, not a picture of
> a terminal."

Tie back to the talk: the *_layout is the interface_* — for a human in tmux,
and for an agent in herdr.

### 1:50 — clean up

- Agent pane: click it, `Ctrl-C`, then `exit`.
- Everything: `./robot_herdr.sh --stop`.

## If herdr is not installed on the demo machine

Do not install live. Show the two commands and the sidebar screenshot in the
slide:

```bash
herdr pane list
herdr pane read w1:p4
```

The tmux examples make the same architectural point with `tmux capture-pane`
and `tmux send-keys`; herdr's advantage is that those calls are first-class and
the UI already knows what an agent is.

## Failure modes to expect

| Symptom | Fix |
|---|---|
| `herdr: command not found` | use the tmux fallback; do not install on stage |
| workspace exists already | re-running `robot_herdr.sh` closes and replaces it |
| agent start times out | the pane is not at a bare shell prompt; click it, press Enter |
| prompt rejected as `agent_blocked` | the agent is waiting on a permission; answer it in the TUI |
| no panes in the sidebar | you are attached to a different herdr session: `herdr session list` |
