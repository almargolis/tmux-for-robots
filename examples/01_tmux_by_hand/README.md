# 01 — tmux by hand (5 minutes)

No robot, no config, nothing to install beyond `tmux` and `python3`. This is
the part to type along with.

```bash
./try_it.sh
```

You get three panes: two small Python programs and one ordinary shell. The
output keeps climbing even when nobody is watching — and either program
crashes on demand when you press a key in its pane.

## The experiment that makes the point

1. Watch the readings for a second.
2. Press **`Ctrl-b`**, release, then **`d`**. You are back in your normal
   terminal; `try_it.sh` has *detached*.
3. Wait ten seconds. Close the terminal window if you like.
4. Open a new terminal and run:

   ```bash
   tmux attach -t demo
   ```

The readings did not restart. They did not pause. They never knew you left.

That is the whole idea: the programs are children of the **tmux server**, not
of your terminal or your SSH connection. The terminal is a replaceable
window onto a session that keeps running.

> Simulating a wifi drop: `Ctrl-b d` is a polite detach. Closing the window or
> killing the SSH client is the rude version — and the result is the same.

## Break one on purpose

Both programs are deliberately fragile. Click into the `sensor loop` pane and
press **any** key: `x`, Space, Enter, anything. The program is not
interactive, so it treats that byte as a corrupted reading and raises.

```
Traceback (most recent call last):
  File ".../sensor.py", line 57, in main
    read_range(fd if saved is not None else None)
  File ".../sensor.py", line 40, in read_range
    raise SensorError(
SensorError: got 'x' while reading /dev/ttyUSB0: this driver has no interactive input

[sensor] exited (status 1) -- the traceback above is the clue.
[sensor] re-launch: ./sensor.py   (or: python3 sensor.py)

%
```

Three things just happened, and all three are the argument for panes:

1. **The traceback is still on screen.** The pane outlived the process. If it
   has scrolled, `Ctrl-b [` enters copy mode and the session keeps 50 000
   lines.
2. **You are at a prompt in the same pane**, in the same directory, with the
   evidence still above you. Read it, fix it, run it again — no second
   terminal, no lost window.
3. **Nothing else noticed.** The camera is still printing, the shell is still
   yours. One process died; the layout survived.

Re-launching is just the command you already know:

```bash
./sensor.py
```

The readings start again at 1: it is a brand-new process. What survived the
crash was the pane, the directory, and the output above it. Try the camera
pane too; press `q` there and read a different traceback.

`Ctrl-C` is the polite stop: the program prints `stopped`, the wrapper prints
its exit status, and you get a prompt instead of a closed window. The wrapper
is a generated file, `$TMPDIR/tmux-demo-demo/sensor.sh` (`--stop` deletes it),
and it is worth reading once.

If you would rather not attach to re-launch, the same thing from outside is:

```bash
tmux send-keys -t demo:0.0 './sensor.py' Enter
```

## The commands worth memorising

| What | Command |
|---|---|
| Start a named session | `tmux new -s robot` |
| List sessions | `tmux ls` |
| Attach | `tmux attach -t robot` |
| Detach (inside tmux) | `Ctrl-b` then `d` |
| New window (inside) | `Ctrl-b` then `c` |
| Split right / down (inside) | `Ctrl-b` then `%` / `"` |
| Move between panes | `Ctrl-b` then arrow keys |
| Kill a session | `tmux kill-session -t robot` |

`Ctrl-b` is the **prefix**: tmux listens for it, then one more key. Press
`Ctrl-b ?` to see every binding. With `${EDITOR}`-style config you can change
the prefix, but there is no need to.

## If you already know GNU screen

| Idea | screen | tmux |
|---|---|---|
| New named session | `screen -S robot` | `tmux new -s robot` |
| List | `screen -ls` | `tmux ls` |
| Attach | `screen -r robot` | `tmux attach -t robot` |
| Detach | `Ctrl-a d` | `Ctrl-b d` |
| New window | `Ctrl-a c` | `Ctrl-b c` |
| Split | plugins / `Ctrl-a \|` | `Ctrl-b %` and `Ctrl-b "` |
| "Type" a command into it | `screen -S robot -X stuff $'cmd\n'` | `tmux send-keys -t robot: cmd Enter` |
| Scrollback | `Ctrl-a [` then arrows | mouse wheel, or `Ctrl-b [` |
| Mouse | no | yes |

Both keep processes alive across a disconnect. tmux gives you real panes,
mouse support, and a scripting interface that is pleasant to read.

## Files

| File | Purpose |
|---|---|
| `try_it.sh` | Creates the disposable `demo` session (or attaches). `--stop` kills it. |
| `sensor.py` | 1 Hz pretend sensor. Press a key and it raises `SensorError`. |
| `camera.py` | 0.5 Hz pretend camera. Press a key and it raises `CameraError`. |
| `tmux.conf` | Optional starter config: mouse, 50k scrollback, labelled panes, `\|` and `-` splits. |

The two programs are about forty lines each and share no code. They exist to
give the panes something that can fail on cue; nothing in them is specific to
tmux.
