# Project memory: tmux-for-robots

Context for anyone (human or agent) continuing work on this repo. Read this
before changing the deck or the examples.

## What this is

A 15-minute talk for hbrobotics.org, announced as **"Using the Linux screen
command to organize processes."** The talk keeps that title, then teaches tmux
(with a short herdr segment) and the rule that matters:

> A multiplexer only saves your processes if it runs **where the processes
> run**. tmux on the laptop preserves views; tmux/systemd on the robot
> preserves work.

The audience uses Linux because of ROS, follows patterns rather than tool
internals, and mostly wants several visible outputs at once. Many use AI chat
uploads rather than TUIs. Keep examples copy-pasteable and free of prerequisites.

## Hard constraints

- **Do not change the announced title.** It appears on slide 1 verbatim.
- **Do not modify** the two reference projects used to build this:
  `robocars2026/` (the real screen-based launch framework) and
  `screen_20261118/` (an earlier partial attempt). Both are sources only.
- **No ROS required** for `examples/`. Pure Python 3.8+ and tmux. Only
  `smarty/` contains real ROS 2 commands.
- Examples must work standalone; do not make them import from each other except
  within `robot_sim/`.
- Target repo: `github.com/almargolis/tmux-for-robots`.

## Layout and where to edit what

| Path | Edit it for |
|---|---|
| `slides/index.html` | slide content, speaker notes, demo cues |
| `slides/custom.css` | typography, grids, overflow fixes |
| `slides/img/*.svg` | the mental-model and "where does tmux run" diagrams |
| `examples/robot_sim/*.py` | the pretend robot's behaviour and topics |
| `examples/01_tmux_by_hand/sensor.py`, `camera.py` | the two pane programs that crash on a keypress |
| `examples/02_tmux_robot/robot_up.sh` | one-session launcher, wrapper generation |
| `examples/03_launch_dir/_launch_common.sh` | per-node launcher, wrapper generation |
| `examples/03_launch_dir/_screen_session.sh` | GNU screen session detection/teardown |
| `examples/herdr/robot_herdr.sh` | herdr workspace, layout, pane ids |
| `smarty/smarty.conf.example` | hosts, ROS setup, map paths, commands |
| `smarty/smarty.sh` | profiles, windows, topic waits |

The deck is reveal.js 5.2.1, vendored under `slides/vendor/` so it works
offline and over Zoom. Do not switch to a CDN.

## Design decisions already made

- **tmux is the backbone; herdr is a ~1.5–3 minute optional segment.** Herdr is
  new and not installed on most robots, so it must never be required.
- The deck reframes the announced title immediately (slide 1 subtitle) instead
  of pretending screen and tmux are the same command.
- `03_launch_dir` mirrors the real `robocars2026/launch` shape: one session per
  node, ordered startup, a shell that stays open after a crash, `status` and
  `stop_all`. It is a re-telling, not a copy.
- All launchers start panes with **generated wrapper scripts**, not immediate
  `send-keys`/`screen -X stuff`. This removes a real startup race (see below).
- `smarty/` uses profiles (`mapping`, `navigation`) and checks for topics
  rather than sleeping.
- `smarty.conf` is git-ignored; `smarty.conf.example` holds the defaults.
- MIT license, GitHub Pages workflow publishing `slides/`.

## Local state (as of the handoff)

- Commits on `main`: `b21aebe` (initial build), `ded4426` (real repo URL),
  plus the commit that added this file.
- No remote is configured; nothing has been pushed.
- Working tree clean; no tmux sessions, screen sockets, sim processes, or herdr
  server left running.
- Only tested on macOS (tmux 3.8, screen 4.00.03, Python 3.15, herdr 0.9.5).
  A Linux pass (tmux 3.x, screen 4.09) is still worth doing before the talk.

## Validating the deck

The deck is authored at 1280×720 and reveal scales to the window. Render slides
by hash index (0-based) and inspect for clipping:

```bash
cd slides
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --no-sandbox --allow-file-access-from-files \
  --window-size=1280,720 --virtual-time-budget=1200 \
  --screenshot=/tmp/slide3.png "file://$PWD/index.html#/3"
```

What to look for:

- Content cut off at the bottom or right edge (the common failure).
- Code blocks whose longest line runs past the panel.
- Duplicate list numbers: reveal styles `ol` at higher specificity, so step
  lists need `.reveal .steps` rules, not `.steps`.
- Table cells spilling: tables use `table-layout: fixed` with
  `overflow-wrap: break-word`.

Slides 5, 6, 10 and 11 in `index.html` (indices 5, 6, 10, 11) were the
overflow-prone ones and are currently clean.

Print/PDF export: open `index.html?print-pdf` in Chrome, print to PDF
(landscape, no margins, backgrounds on).

## Validating the examples

Run from each directory. Use throwaway ports so a stray broker does not mask a
failure.

```bash
# 01 -- readings, detach, crash on a keypress, re-launch
cd examples/01_tmux_by_hand
./try_it.sh
tmux list-panes -t demo:0 -F '#{pane_index} #{pane_title}'
tmux send-keys -t demo:0.0 'x'                    # pretend to press a key
sleep 2                                           # traceback + prompt appear
tmux list-panes -t demo:0 -F '#{pane_index} #{pane_current_command}'
tmux send-keys -t demo:0.0 './sensor.py' Enter    # re-launch in place
tmux send-keys -t demo:0.1 C-c                    # polite stop: pane stays
./try_it.sh --stop

# 02 -- one session, one pane per node, crash stays readable
cd examples/02_tmux_robot
MINIBUS_PORT=7782 CAMERA_ARGS="--crash-after 4" ./robot_up.sh --headless
sleep 7
grep "pane kept open" logs/camera.log
./robot_down.sh

# 03 -- one session per node, tmux and screen
cd examples/03_launch_dir
./launch_all && sleep 2 && ./status && ./stop_all
MUX=screen ./launch_all && sleep 3 && MUX=screen ./status
MUX=screen ./stop_all

# herdr -- layout, pane ids, teardown
cd examples/herdr
./robot_herdr.sh
source "${TMPDIR:-/tmp}/herdr-robot-sim/panes.env"
herdr pane layout --pane "$BROKER_PANE"
./robot_herdr.sh --stop
herdr server stop

# smarty -- plan, then a headless smoke test
cd smarty
./smarty.sh mapping --dry-run
./smarty.sh mapping --no-wait --headless
./smarty.sh status && ./smarty.sh stop
```

Expected smoke-test results:

- 01: three panes (`sensor loop`, `camera loop`, `a normal shell`); a keypress
  in either program pane leaves a traceback plus a prompt; `Ctrl-C` stops a
  program without closing its pane; re-launching prints readings from 1 again.
- 02: six panes; `logs/camera.log` ends with `pane kept open` after a forced
  crash; `robot_down.sh` leaves no sim processes.
- 03: five `running` entries; after `stop_all`, no sessions remain.
- herdr: six panes in a 3×2 grid; `panes.env` exports `AGENT_PANE`.
- smarty: windows `robot`, `sensors`, `slam` (plus `drive` when tethered).

## Tooling quirks that cost time

**tmux**

- Do **not** `send-keys` immediately into a freshly created pane: the shell may
  not be ready, and the command gets mangled and never runs. Start the pane
  with the command, or with a generated wrapper script.
- `tmux set-option` fails if no session exists yet under `set -e`. Create the
  first pane, then set options.
- Splitting the newest pane repeatedly eventually yields "no space for a new
  pane". Re-run `select-layout tiled` after each split, or split a balanced
  tree.
- Under this agent harness, `capture-pane` can render blank even when the pane
  is fine. Verify with `pipe-pane` to a file, `ps`, a listening port, or the
  headless logs — not capture alone.
- Pane targets are `session:window.pane` (`demo:0.1`). `demo:1` means *window*
  1 and fails with "can't find window: 1" in a single-window session.
- `Ctrl-C` goes to the whole foreground process group. In a program-then-shell
  wrapper the wrapper shell gets it too and the pane closes, taking the
  traceback with it. `01_tmux_by_hand`'s generated wrapper traps `INT` and
  resets it in a subshell so the program still stops; `02`/`03` do not, which
  is why they ship `robot_down.sh` / `stop_all`.

**GNU screen**

- `screen -ls | grep -q` is unreliable under `set -o pipefail`: grep exits
  early, screen gets SIGPIPE, and the pipeline reports failure even on a match.
  That produced duplicate sessions and a blind `status`. Use
  `_screen_session.sh` (captures output, then parses).
- `screen -X stuff` did not reliably deliver commands on macOS screen 4.00.03.
  Start sessions with a command instead: `screen -dmS name bash wrapper`.
- `status` under screen reports session existence, not the child process, so a
  crashed node still looks "running". Documented in
  `examples/03_launch_dir/README.md`.

**herdr**

- Pane ids look like `w1:p2`; `workspace create` returns JSON including
  `result.root_pane.pane_id`.
- `pane split --ratio` is relative to the parent split, and `--ratio` semantics
  are easy to invert. The current 3×2 layout uses `0.667` on the root split to
  make a one-third right column; verify with `herdr pane layout`.
- `pane run` sends text and Enter; `send-text` + `send-keys Enter` is the
  two-step form.
- Start a headless server with `herdr server`; **stop it with
  `herdr server stop`** after testing.
- The demo writes pane ids to `${TMPDIR:-/tmp}/herdr-robot-sim/panes.env`
  (`AGENT_PANE`, `BROKER_PANE`, …). Use them instead of parsing JSON on stage.

**ssh + quoting**

- `ssh` joins arguments and lets the remote shell re-parse them. `smarty.sh`
  base64-encodes the whole remote script to avoid multi-line quoting traps.
  Keep that approach.

## Live-demo fallbacks

- Deck notes on slide 6, 7, 9, 11 include the commands and what to do if a
  demo fails. The rule is: do not debug live for more than ~20 seconds.
- If tmux misbehaves, the slide screenshots are the fallback.
- If herdr is missing, show `herdr pane list` / `pane read` and move on. Do not
  install it on stage.
- `AGENT_DEMO.md` lists the expected failure modes (`agent_blocked`, wrong
  pane state, existing workspace).

## Sensible next changes

1. Replace the example commands/hosts in `smarty.conf.example` with the real
   robot values (base package, topics, map paths), then run `--dry-run`.
2. Do one Linux pass of all examples and the deck.
3. Add repository topics on GitHub for discoverability (tmux, gnu-screen, ros2,
   robotics, herdr, hbrobotics) and the Pages link in the About section.
4. Optional: commit a PDF export of the deck and a short fallback demo video.
5. If the talk overruns, the herdr segment (slide 11) is the intended cut.

## Publishing

```bash
gh repo create almargolis/tmux-for-robots --public --source=. --remote=origin --push
```

Then **Settings → Pages → Source: GitHub Actions**. The workflow in
`.github/workflows/pages.yml` deploys `slides/` on pushes to `main`, giving
`https://almargolis.github.io/tmux-for-robots/`.
