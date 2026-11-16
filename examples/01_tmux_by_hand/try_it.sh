#!/usr/bin/env bash
#
# try_it.sh -- a disposable tmux session for the hands-on part of the talk.
#
#   ./try_it.sh          create it (or attach if it already exists)
#   ./try_it.sh --stop   throw it away
#
# Three panes, all doing something visible. Nothing here talks to the robot;
# the point is to feel the mechanics: detach, reattach, and watch the counters
# keep going while no terminal is attached.

set -euo pipefail
SESSION="${SESSION:-demo}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${1:-}" = "--stop" ]; then
    tmux kill-session -t "=$SESSION" 2>/dev/null && echo "killed '$SESSION'" || echo "'$SESSION' is not running"
    exit 0
fi

if tmux has-session -t "=$SESSION" 2>/dev/null; then
    echo "session '$SESSION' already exists -- attaching"
    exec tmux attach -t "=$SESSION"
fi

sensor_loop='i=0; while :; do i=$((i+1)); printf "sensor reading %3d   %s\n" "$i" "$(date +%T)"; sleep 1; done'
camera_loop='i=0; while :; do i=$((i+1)); printf "camera frame   %3d   %s\n" "$i" "$(date +%T)"; sleep 2; done'

# One server process owns the session. Our terminal is only a client.
# The loops are passed as the pane's command, not typed, so there is no race
# with the shell starting up. (When a pane command exits, the pane closes.)
first=$(tmux new-session -d -s "$SESSION" -x 200 -y 50 -c "$HERE" \
    -P -F '#{pane_id}' "$sensor_loop")

# Make it pleasant: mouse, readable borders, and a title on every pane.
tmux set-option -t "$SESSION" mouse on
tmux set-option -t "$SESSION" history-limit 50000
tmux set-option -w -t "$SESSION:" pane-border-status top
tmux set-option -w -t "$SESSION:" pane-border-format ' #{pane_index} · #{pane_title} '
tmux select-pane -t "$first" -T "sensor loop"

second=$(tmux split-window -t "$first" -c "$HERE" -P -F '#{pane_id}' "$camera_loop")
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
echo "  stop:   $HERE/try_it.sh --stop"

if [ -t 0 ] && [ -t 1 ]; then
    exec tmux attach -t "=$SESSION"
fi
