# tmux for robots

Slides and runnable examples for the hbrobotics.org talk
**“Using the Linux screen command to organize processes.”**

The announced title says *screen*. The talk is about the same idea with better
ergonomics — **tmux** — plus one new option, **herdr**, and the failure mode
that catches almost everyone:

> Your robot's processes are children of `sshd` on the robot.
> Close the laptop, lose wifi, and they get `SIGHUP`.
> A multiplexer only saves them if it runs **where the processes run**.

Everything here is standalone: **Python 3.8+ and tmux**, no ROS, no Docker, no
accounts. The examples are a pretend robot, so you can practise the organisation
without risking a real one.

## Quick start (60 seconds)

```bash
git clone https://github.com/almargolis/tmux-for-robots.git
cd tmux-for-robots

# 1. Watch readings keep running after you detach and close the terminal.
cd examples/01_tmux_by_hand
./try_it.sh
#    Ctrl-b d to detach, then:  tmux attach -t demo
#    press any key in a program pane to crash it and read the traceback

# 2. Start a whole fake robot: one command, one pane per process.
cd ../02_tmux_robot
./robot_up.sh
#    ./robot_down.sh when you are done
```

No tmux yet?

```bash
sudo apt install tmux        # Debian/Ubuntu/Raspberry Pi OS
brew install tmux            # macOS
```

## The slides

Open [`slides/index.html`](slides/index.html) in a browser. reveal.js is
vendored in the repo, so it works offline and over Zoom screen share with no
network.

| Key | Does |
|---|---|
| `→` / `Space` | next slide |
| `S` | speaker notes, including timing and demo cues |
| `F` | full screen |
| `?` | all shortcuts |

To export a PDF, open `slides/index.html?print-pdf` in Chrome, then print to PDF
(landscape, no margins, background graphics on).

The deck is also published with GitHub Pages — see [Publishing](#publishing).

## The 15-minute talk

| Time | Slide | Point |
|---|---|---|
| 0:00 | Title | Announced title, then the reframe: same idea, better tools |
| 0:30 | The ten-window problem | 10 SSH sessions, 1 wifi drop, 0 survivors |
| 2:00 | Credit where it's due | screen got the model right; the interface aged |
| 3:00 | The mental model | Disposable client, server owns the processes |
| 4:30 | tmux in 60 seconds | Four commands you actually need |
| 5:30 | **Live: the 30-second proof** | Counters survive detach + closed terminal |
| 7:30 | One robot, one command | tiled panes; crash leaves evidence, not a closed window |
| 8:30 | Order is a dependency | wait for the port/topic, not `sleep 2`; tethered vs headless |
| 10:00 | Smarty | A paste-athon becomes `./smarty.sh mapping` |
| 11:30 | **Where must tmux run?** | Laptop tmux = views; robot tmux/systemd = survival |
| 13:00 | herdr | Same model, agent-aware panes, scriptable socket API |
| 14:30 | Take one thing home | `tmux new -s robot`; then steal the pattern |

## What's in the repo

```
slides/               reveal.js deck (vendored), speaker notes, diagrams
examples/
  robot_sim/          a pretend robot: broker + 5 stdlib-only Python nodes
  01_tmux_by_hand/    the 5-minute hands-on: detach, attach, crash, re-launch
  02_tmux_robot/      whole robot in one tmux session, ordered startup, logs
  03_launch_dir/      one script + one session per process (the real pattern)
  herdr/              the same robot laid out with herdr, plus an agent demo
smarty/               Smarty.md's cheat sheet turned into one tmux command
```

Start with [`examples/robot_sim/README.md`](examples/robot_sim/README.md) if you
want to know what the fake robot is doing. Start with
[`examples/02_tmux_robot/`](examples/02_tmux_robot/) if you just want the
pattern.

## The examples, and what each one teaches

| Example | Shape | Use it when |
|---|---|---|
| [`01_tmux_by_hand`](examples/01_tmux_by_hand/) | one session, three panes, a crash on demand | you are learning tmux, or teaching it |
| [`02_tmux_robot`](examples/02_tmux_robot/) | one session, one pane per node, generated wrappers | you want to *watch* the whole robot at once |
| [`03_launch_dir`](examples/03_launch_dir/) | one session per node, `launch_*` / `stop_all` | processes need independent lifecycles |
| [`herdr`](examples/herdr/) | herdr workspace, CLI/socket API, agent demo | you want an agent to inspect or drive the layout |
| [`smarty`](smarty/) | real ROS 2 launch commands, one profile per workflow | you have a cheat sheet like Smarty.md |

The `launch_*` shape in `03_launch_dir` is adapted from the real
`robocars2026/launch/` framework (GNU screen, one session per node, ordered
startup, a shell that stays open after a crash). The original is untouched; this
is a small, ROS-free re-telling you can pull apart.

## Running it on a real robot

1. Put the launcher on the robot, not only on your laptop.
2. Start it at boot (`@reboot` in cron, or a systemd user service — see
   [`robot.service`](examples/02_tmux_robot/robot.service)).
3. Replace the `sleep` in your current launch sequence with a readiness check:
   a TCP port, a ROS topic, or a node's "ready" line.
4. Keep the pane open when a node exits, so the traceback is still there when
   you reconnect.
5. Optional: keep the *views* in tmux on the laptop too, especially when you
   work with several robots at once.

## Requirements

| Thing | Needed for | Notes |
|---|---|---|
| Python 3.8+ | the pretend robot | standard library only |
| tmux 3.x | examples 01–03, smarty | `apt install tmux`, `brew install tmux` |
| GNU screen | `MUX=screen` in `03_launch_dir` | optional fallback |
| herdr 0.9+ | `examples/herdr` | `curl -fsSL https://herdr.dev/install.sh \| sh`, or `brew install herdr` |
| ROS 2 | `smarty/` | only if you run the real commands |

## Publishing

The deck is plain static HTML. To host it on GitHub Pages:

1. Push this repo to GitHub.
2. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
3. The included workflow ([`.github/workflows/pages.yml`](.github/workflows/pages.yml))
   publishes `slides/` on every push to `main`.

The deck then lives at `https://almargolis.github.io/tmux-for-robots/`.

## Credits

- Built for [hbrobotics.org](https://hbrobotics.org).
- The launch-directory pattern and the keep-open shell come from the
  `robocars2026/launch/` framework.
- [Smarty.md](https://docs.google.com/document/d/1Sg-Xfg9Mm2aaPD8RT6Pu--qHWCRthnQeKTDLjL73_3Q/edit?usp=sharing)
  is the robot-startup cheat sheet that `smarty/` automates.
- [reveal.js](https://revealjs.com) is vendored under `slides/vendor/` (MIT).
- tmux, GNU screen, and [herdr](https://herdr.dev) belong to their authors.

## License

MIT — see [LICENSE](LICENSE). Use the examples, rewrite them, put them in your
own robot.
