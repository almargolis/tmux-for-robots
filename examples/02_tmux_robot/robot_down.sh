#!/usr/bin/env bash
#
# robot_down.sh -- stop the robot started by robot_up.sh.
#
# Polite shutdown: send Ctrl-C to every pane (so each program can stop its
# motors, close files, etc.), newest first, then close the session.

set -uo pipefail
SESSION="${SESSION:-robot}"

if ! tmux has-session -t "=$SESSION" 2>/dev/null; then
    echo "tmux session '$SESSION' is not running"
    exit 0
fi

# Reverse pane order: the broker (pane 0) goes last.
for pane in $(tmux list-panes -s -t "=$SESSION" -F '#{pane_index}' | sort -rn); do
    tmux send-keys -t "$SESSION:.$pane" C-c 2>/dev/null || true
    sleep 0.2
done
sleep 1
tmux kill-session -t "=$SESSION"
rm -rf "${TMPDIR:-/tmp}/tmux-robot-$SESSION"
echo "stopped tmux session '$SESSION'"
