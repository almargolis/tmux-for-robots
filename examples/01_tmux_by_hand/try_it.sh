#!/usr/bin/env bash
#
# try_it.sh -- a disposable tmux session for the hands-on part of the talk.
#
#   ./try_it.sh          create it (or attach if it already exists)
#   ./try_it.sh --stop   throw it away
#
# Three panes, all doing something visible: two small Python programs and one
# ordinary shell. Nothing here talks to the robot; the point is to feel the
# mechanics: detach, reattach, and watch the output keep going while no
# terminal is attached.
#
# Press a key in either program's pane and it raises an exception on purpose.
# The traceback stays on screen, the pane hands you a prompt, and the program
# starts again when you ask it to -- the process died, not the session.

set -euo pipefail
SESSION="${SESSION:-demo}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="${TMPDIR:-/tmp}/tmux-demo-$SESSION"

if [ "${1:-}" = "--stop" ]; then
    tmux kill-session -t "=$SESSION" 2>/dev/null && echo "killed '$SESSION'" || echo "'$SESSION' is not running"
    rm -rf "$RUN_DIR"
    exit 0
fi

if tmux has-session -t "=$SESSION" 2>/dev/null; then
    echo "session '$SESSION' already exists -- attaching"
    exec tmux attach -t "=$SESSION"
fi

# write_wrapper NAME SCRIPT -> prints the wrapper's path
#
# A pane runs one program and then stays open with a shell, so a crash leaves
# a readable traceback and a prompt to re-launch from. The wrapper ignores
# Ctrl-C but the program does not (the subshell puts the default handler
# back), so stopping a program politely does not take its window with it.
write_wrapper() {
    local name="$1" script="$2" wrapper="$RUN_DIR/$1.sh"
    {
        printf '#!/usr/bin/env bash\n'
        printf 'cd %q || exit 1\n' "$HERE"
        printf "trap '' INT\n"
        printf '( trap - INT; exec ./%s )\n' "$script"
        printf 'status=$?\n'
        printf 'trap - INT\n'
        printf 'printf "\\n[%s] exited (status %%s) -- the traceback above is the clue.\\n" "$status"\n' "$name"
        printf 'printf "[%s] re-launch: ./%s   (or: python3 %s)\\n\\n"\n' "$name" "$script" "$script"
        printf 'exec "${SHELL:-bash}" -i\n'
    } > "$wrapper"
    chmod +x "$wrapper"
    printf '%s' "$wrapper"
}

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

# One server process owns the session. Our terminal is only a client. Each
# pane is started with a command (never typed into a fresh shell), so nothing
# races the shell's own startup.
sensor_wrapper=$(write_wrapper sensor sensor.py)
first=$(tmux new-session -d -s "$SESSION" -x 200 -y 50 -c "$HERE" \
    -P -F '#{pane_id}' "bash $(printf '%q' "$sensor_wrapper")")

# Make it pleasant: mouse, readable borders, and a title on every pane.
tmux set-option -t "$SESSION" mouse on
tmux set-option -t "$SESSION" history-limit 50000
tmux set-option -w -t "$SESSION:" pane-border-status top
tmux set-option -w -t "$SESSION:" pane-border-format ' #{pane_index} · #{pane_title} '
tmux select-pane -t "$first" -T "sensor loop"

camera_wrapper=$(write_wrapper camera camera.py)
second=$(tmux split-window -t "$first" -c "$HERE" -P -F '#{pane_id}' \
    "bash $(printf '%q' "$camera_wrapper")")
tmux select-pane -t "$second" -T "camera loop"

# An ordinary shell pane: this one is for the audience to type in. Starting
# the shell as the pane command (rather than typing into a just-created pane)
# avoids racing the shell's own startup.
banner='printf "\n  This shell is inside tmux. Try: ls, then Ctrl-b d.\n\n"; exec "${SHELL:-bash}" -i'
third=$(tmux split-window -t "$second" -c "$HERE" -P -F '#{pane_id}' "$banner")
tmux select-pane -t "$third" -T "a normal shell"

tmux select-layout -t "$SESSION:" tiled
tmux select-pane -t "$third"

echo "created tmux session '$SESSION'"
echo "  detach: Ctrl-b then d        reattach: tmux attach -t $SESSION"
echo "  crash:  press any key in a program pane (it raises on purpose)"
echo "  stop:   $HERE/try_it.sh --stop"

if [ -t 0 ] && [ -t 1 ]; then
    exec tmux attach -t "=$SESSION"
fi
