# _launch_common.sh -- shared logic for the launch_<node> scripts in this directory.
#
# Modeled on a real robot's launch directory (robocars2026/launch): one tiny
# script per process + this shared file. A launch_<node> script sets a few
# variables and sources this file:
#
#     SESSION=navigator                    # tmux/screen session name
#     NODE_CMD="python3 navigator.py"      # what to run (in ../robot_sim)
#     NEEDS_PORT=7777                      # optional: wait for this port first
#     LAUNCH_DEFAULT=foreground            # optional: interactive tools
#     source "$(dirname "${BASH_SOURCE[0]}")/_launch_common.sh"
#
# The resulting script:
#
#     ./launch_navigator        default mode (detached unless LAUNCH_DEFAULT)
#     ./launch_navigator -f     foreground: run right here, Ctrl-C to stop
#     ./launch_navigator -d     detached: in its own session "navigator"
#
# Detached nodes are TYPED into a normal shell inside the session, so after
# a crash the window stays open with the traceback, and Up-arrow re-runs it.
#
# Multiplexer: tmux by default. Set MUX=screen to use GNU screen instead --
# the ideas are identical, only the commands differ.
#
#     tmux ls                      screen -ls                 list
#     tmux attach -t navigator     screen -r navigator        look (Ctrl-b d / Ctrl-a d to leave)
#     ./stop_all                                              stop everything

set -euo pipefail

: "${SESSION:?caller must set SESSION}"
: "${NODE_CMD:?caller must set NODE_CMD}"
MUX="${MUX:-tmux}"

_caller="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
LAUNCH_DIR="$(cd "$(dirname "$_caller")" && pwd)"
WORK_DIR="$(cd "$LAUNCH_DIR/../robot_sim" && pwd)"     # where the nodes live
cd "$WORK_DIR"

# If your robot uses a Python virtualenv, activate it here, e.g.:
# source "${ROBOT_VENV:-$HOME/robot/.venv}/bin/activate"

mode="${LAUNCH_DEFAULT:-detached}"
case "${1:-}" in
    -f | --foreground) mode=foreground ;;
    -d | --detached)   mode=detached ;;
    "") ;;
    *) echo "usage: $(basename "$_caller") [-f|--foreground | -d|--detached]" >&2; exit 2 ;;
esac

# ---- launch order: wait for whatever this node depends on -----------------
if [ -n "${NEEDS_PORT:-}" ]; then
    if ! python3 "$WORK_DIR/wait_for_port.py" "$NEEDS_PORT" --timeout 15; then
        echo "[$SESSION] nothing listening on port $NEEDS_PORT -- start the broker first (./launch_broker)" >&2
        exit 1
    fi
fi

if [ "$mode" = foreground ]; then
    echo "[$SESSION] foreground: $NODE_CMD   (Ctrl-C to stop)"
    # shellcheck disable=SC2086
    exec $NODE_CMD
fi

# ---- detached: one session per node ----------------------------------------
# shellcheck source=_screen_session.sh
source "$(dirname "${BASH_SOURCE[0]}")/_screen_session.sh"

is_running() {
    if [ "$MUX" = screen ]; then
        screen_has_session "$SESSION"
    else
        tmux has-session -t "=$SESSION" 2>/dev/null
    fi
}

if is_running; then
    echo "[$SESSION] already running -- look at it with: $MUX $([ "$MUX" = screen ] && echo "-r" || echo "attach -t") $SESSION"
    exit 0
fi

# A generated wrapper runs the node, then leaves an interactive shell with the
# command in history. Both multiplexers start the session *with* this script.
# Starting with a command, rather than typing into a brand-new shell, avoids a
# startup race (and screen's `-X stuff` is unreliable on some builds).
RUN_DIR="${TMPDIR:-/tmp}/launch-$SESSION"
rm -rf "$RUN_DIR"; mkdir -p "$RUN_DIR"
rc="$RUN_DIR/$SESSION.rc"
wrapper="$RUN_DIR/$SESSION.sh"
{
    echo '[ -f ~/.bashrc ] && source ~/.bashrc'
    printf 'history -s %q\n' "$NODE_CMD"
    printf "PS1='[%s] \\$ '\n" "$SESSION"
} > "$rc"
env_line=''
if [ -n "${MINIBUS_PORT:-}" ]; then env_line="export MINIBUS_PORT=$MINIBUS_PORT"$'\n'; fi
printf '#!/usr/bin/env bash\nexport BASH_SILENCE_DEPRECATION_WARNING=1\ncd %q\n%s[ -f ~/.bashrc ] && source ~/.bashrc\n%s\nec=$?\nprintf "\\n[%s] exited (status %%s) -- pane kept open\\n" "$ec"\nprintf "[%s] Up-arrow + Enter re-runs it.\\n\\n"\nexec bash --rcfile %q\n' \
    "$WORK_DIR" "$env_line" "$NODE_CMD" "$SESSION" "$SESSION" "$rc" > "$wrapper"
chmod +x "$wrapper"

if [ "$MUX" = screen ]; then
    screen -h 20000 -dmS "$SESSION" bash "$wrapper"       # new detached session
    echo "[$SESSION] started: $NODE_CMD    look: screen -r $SESSION    leave: Ctrl-a d"
else
    tmux new-session -d -s "$SESSION" -c "$WORK_DIR" "bash $(printf '%q' "$wrapper")"
    tmux set-option -t "$SESSION" mouse on
    tmux set-option -t "$SESSION" history-limit 50000
    echo "[$SESSION] started: $NODE_CMD    look: tmux attach -t $SESSION    leave: Ctrl-b d"
fi
