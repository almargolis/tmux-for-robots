# herdr — the same robot, agent-aware

[herdr](https://herdr.dev) is a terminal workspace manager built for coding
agents. It has the same client/server model as tmux — panes keep running when
you detach or lose SSH — but it is mouse-first and it knows which panes contain
an agent and whether that agent is working, blocked, or done.

This is the optional last segment of the talk: about two minutes, after the
"where must tmux run?" slide.

## Run it

```bash
# herdr 0.9+; install with the script or Homebrew
curl -fsSL https://herdr.dev/install.sh | sh
# brew install herdr

cd examples/herdr
./robot_herdr.sh        # starts a headless server if needed
herdr                   # attach the TUI
```

Click the **robot-sim** workspace. You get a 3×2 grid:

```
┌ broker ────────┬ lidar ─────────┬ camera ────────┐
│ READY :7777    │ front 212.3 cm │ I see: nothing │
│ + lidar        │ front 198.0 cm │ I see: stop    │
├ navigator ─────┼ motors ────────┼ agent-shell ───┤
│ path clear     │ ^^ speed 66    │ $              │
│ stop sign      │ WATCHDOG armed │                │
└────────────────┴────────────────┴────────────────┘
```

The panes are running the same `../robot_sim/` nodes as the tmux examples. The
only difference is who owns the layout.

Stop it when you are done:

```bash
./robot_herdr.sh --stop
```

The script also closes a stale `robot-sim` workspace first, so re-running it is
safe.

## What to point at during the talk

1. **The sidebar.** The camera pane can be made to exit and the workspace shows
   it. (Try `herdr pane run <camera-pane> 'python3 camera.py --crash-after 1'`.)
2. **Clickable split borders.** Drag one. The tmux version needs a key binding;
   this needs a mouse. That is the trade.
3. **The CLI sees the UI.** In another terminal:

   ```bash
   herdr pane list
   herdr pane read w1:p2 --lines 5
   herdr pane layout --pane w1:p1
   ```

   The same commands an agent would use. This is the "the multiplexer is an
   API" point.
4. **Tab and workspace persistence.** Close the TUI, open it again, the
   workspace is still there. Same idea as `tmux attach`, different furniture.

## How the script drives herdr

No screen-scraping, no keystroke timing: herdr's CLI speaks to a local socket
and returns JSON.

```bash
herdr workspace create --label robot-sim --cwd "$SIM" --env MINIBUS_PORT=7777
herdr pane split w1:p1 --direction right --ratio 0.667 --cwd "$SIM"
herdr pane run w1:p2 'python3 lidar.py'
herdr pane rename w1:p2 lidar
```

A few details worth knowing if you write your own:

- `workspace create` returns `result.root_pane.pane_id`; keep it.
- Splitting the *same* pane repeatedly makes slivers. Split a small balanced
  tree instead (the script builds left third, middle third, right third).
- `--ratio` is measured from the parent split; `0.667` on the root produced the
  intended one-third column here.
- `pane run` sends text **and** Enter. `pane send-text` + `pane send-keys Enter`
  is the two-step version.
- Launch order is still checked with `wait_for_port.py` before any node starts.

## herdr vs tmux, honestly

| | tmux | herdr |
|---|---|---|
| Installed on robot images | almost always | rarely |
| Scripting | `send-keys`, formats, hooks | CLI + JSON socket API |
| Panes | keyboard | mouse and keyboard |
| Agent awareness | you build it | sidebar + `herdr agent` commands |
| SSH survival | yes | yes |
| Maturity | decades | new (0.9.x) |

Use tmux for the robot you have to support today. Use herdr where a human and an
agent are both looking at the same panes. Nothing in the tmux examples depends
on herdr, and nothing here depends on tmux.

## The same catch applies

herdr keeps panes alive on the machine where its **server** runs. `./robot_herdr.sh`
on your laptop organises laptop views; the `python3` nodes it starts are local,
so they do survive your SSH client. If the nodes should be on the robot, run the
workspace there (or run the robot's own launcher under systemd and attach to it).

## Files

| File | Purpose |
|---|---|
| `robot_herdr.sh` | create/stop the `robot-sim` workspace and its 3×2 layout |
| [`AGENT_DEMO.md`](AGENT_DEMO.md) | a two-minute live runbook for the agent segment |
