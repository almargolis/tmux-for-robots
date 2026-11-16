# 01 — tmux by hand (5 minutes)

No robot, no config, nothing to install beyond `tmux`. This is the part to
type along with.

```bash
./try_it.sh
```

You get three panes: two loops counting, one ordinary shell. The numbers keep
climbing even when nobody is watching.

## The experiment that makes the point

1. Watch the counters for a second.
2. Press **`Ctrl-b`**, release, then **`d`**. You are back in your normal
   terminal; `try_it.sh` has *detached*.
3. Wait ten seconds. Close the terminal window if you like.
4. Open a new terminal and run:

   ```bash
   tmux attach -t demo
   ```

The counters did not restart. They did not pause. They never knew you left.

That is the whole idea: the programs are children of the **tmux server**, not
of your terminal or your SSH connection. The terminal is a replaceable
window onto a session that keeps running.

> Simulating a wifi drop: `Ctrl-b d` is a polite detach. Closing the window or
> killing the SSH client is the rude version — and the result is the same.

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
| `tmux.conf` | Optional starter config: mouse, 50k scrollback, labelled panes, `\|` and `-` splits. |
