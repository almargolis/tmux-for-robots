#!/usr/bin/env bash
#
# robot_up.sh -- start the whole (pretend) robot in ONE tmux session,
# one pane per process, all visible at once.
#
#   ./robot_up.sh              auto: tethered if run from a terminal,
#                              headless if not (cron @reboot, systemd, ssh -T)
#   ./robot_up.sh --tethered   start, include teleop, and attach
#   ./robot_up.sh --headless   start detached, no teleop, log panes to files
#
# Then:
#   tmux attach -t robot       look at it again (after a wifi drop, etc.)
#   Ctrl-b d                   detach -- everything keeps running
#   ./robot_down.sh            stop it all politely
#
# How it works -- the whole trick is three tmux commands:
#   tmux new-session -d ...    create a session in the background
#   tmux split-window ...      add a pane
#   tmux select-layout tiled   arrange them
#
# Each pane runs a small generated wrapper (in $TMPDIR): it runs the node,
# then drops into an interactive shell with that command in history. So when
# a node crashes, the pane stays open with the traceback AND you can press
# Up-arrow + Enter to run it again. That is the behaviour people miss when
# they just run "python node.py &".

set -euo pipefail

SESSION="${SESSION:-robot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM="$(cd "$HERE/../robot_sim" && pwd)"
LOGDIR="${LOGDIR:-$HERE/logs}"
PORT="${MINIBUS_PORT:-7777}"
RUN_DIR="${TMPDIR:-/tmp}/tmux-robot-$SESSION"

# ---- tethered or headless? ------------------------------------------------
mode=auto
case "${1:-}" in
    --tethered) mode=tethered ;;
    --headless) mode=headless ;;
    "") ;;
    *) echo "usage: $0 [--tethered | --headless]" >&2; exit 2 ;;
esac
if [ "$mode" = auto ]; then
    # A human is watching if stdin and stdout are a real terminal.
    if [ -t 0 ] && [ -t 1 ]; then mode=tethered; else mode=headless; fi
fi

# ---- already running? just (re)attach -------------------------------------
if tmux has-session -t "=$SESSION" 2>/dev/null; then
    echo "tmux session '$SESSION' is already running."
    if [ "$mode" = tethered ] && [ -t 0 ] && [ -t 1 ]; then
        if [ -n "${TMUX:-}" ]; then exec tmux switch-client -t "=$SESSION"; fi
        exec tmux attach -t "=$SESSION"
    fi
    exit 0
fi

# ---- generated keep-open wrapper ------------------------------------------
# write_wrapper NAME COMMAND -> prints the wrapper's path
# The wrapper is a real file, so nothing races the shell's startup and there
# are no nested-quoting puzzles.
write_wrapper() {
    local name="$1" cmd="$2"
    local wrapper="$RUN_DIR/$name.sh" rc="$RUN_DIR/$name.rc"

    {
        echo '[ -f ~/.bashrc ] && source ~/.bashrc'
        printf 'history -s %q\n' "$cmd"
        printf "PS1='[%s] \\$ '\n" "$name"
    } > "$rc"

    local env_line=''
    if [ -n "${MINIBUS_PORT:-}" ]; then env_line="export MINIBUS_PORT=$MINIBUS_PORT"$'\n'; fi

    printf '#!/usr/bin/env bash\nexport BASH_SILENCE_DEPRECATION_WARNING=1\ncd %q\n[ -f ~/.bashrc ] && source ~/.bashrc\n%s%s\nec=$?\nprintf "\\n[%s] exited (status %%s) -- pane kept open\\n" "$ec"\nprintf "[%s] Up-arrow + Enter re-runs it. Ctrl-D closes the pane.\\n\\n"\nexec bash --rcfile %q\n' \
        "$SIM" "$env_line" "$cmd" "$name" "$name" "$rc" > "$wrapper"
    chmod +x "$wrapper"
    printf '%s' "$wrapper"
}

# add_pane NAME COMMAND -> splits the current window, prints the new pane id
add_pane() {
    local name="$1" cmd="$2" wrapper pane
    wrapper="$(write_wrapper "$name" "$cmd")"
    pane=$(tmux split-window -t "$SESSION:" -c "$SIM" -P -F '#{pane_id}' \
        "bash $(printf '%q' "$wrapper")")
    tmux select-pane -t "$pane" -T "$name"
    # Re-tile now: splitting the newest pane over and over would make each
    # new pane half the size of the last ("no space for a new pane").
    tmux select-layout -t "$SESSION:" tiled
    if [ "$mode" = headless ]; then
        mkdir -p "$LOGDIR"
        : > "$LOGDIR/$name.log"
        tmux pipe-pane -t "$pane" -o "cat >> $(printf '%q' "$LOGDIR/$name.log")"
    fi
    printf '%s' "$pane"
}

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

# ---- 1. broker in the first pane; session options -------------------------
broker_wrapper="$(write_wrapper broker 'python3 broker.py')"
broker_pane=$(tmux new-session -d -s "$SESSION" -n robot -c "$SIM" -x 220 -y 55 \
    -P -F '#{pane_id}' "bash $(printf '%q' "$broker_wrapper")")
tmux select-pane -t "$broker_pane" -T broker

if [ "$mode" = headless ]; then
    mkdir -p "$LOGDIR"
    : > "$LOGDIR/broker.log"
    tmux pipe-pane -t "$broker_pane" -o "cat >> $(printf '%q' "$LOGDIR/broker.log")"
fi

tmux set-option -t "$SESSION" mouse on
tmux set-option -t "$SESSION" history-limit 50000
tmux set-option -t "$SESSION" status-left ' #[bold]robot '
tmux set-option -w -t "$SESSION:" pane-border-status top
tmux set-option -w -t "$SESSION:" pane-border-format ' #{pane_index} · #{pane_title} '

# ---- 2. WAIT until the broker really answers ------------------------------
echo "waiting for the broker on port $PORT ..."
if ! python3 "$SIM/wait_for_port.py" "$PORT" --timeout 15; then
    echo "broker did not start -- inspect it with: tmux attach -t $SESSION" >&2
    tmux capture-pane -p -t "$broker_pane" >&2 || true
    exit 1
fi

# ---- 3. everything else, one pane each ------------------------------------
add_pane lidar     'python3 lidar.py' >/dev/null
add_pane camera    "python3 camera.py ${CAMERA_ARGS:-}" >/dev/null
add_pane navigator 'python3 navigator.py' >/dev/null
add_pane motors    'python3 motors.py' >/dev/null

if [ "$mode" = tethered ]; then
    # Interactive tools only make sense when a human is attached.
    teleop_pane="$(add_pane teleop 'python3 teleop.py')"
else
    # Headless: one pane showing every node's log, so an ssh visitor sees
    # the whole robot at a glance. Its own log is deliberately not included.
    console_cmd="tail -n 30 -F $(printf '%q' "$LOGDIR")/{broker,lidar,camera,navigator,motors}.log"
    add_pane console "$console_cmd" >/dev/null
fi

tmux select-layout -t "$SESSION:" tiled

echo "started tmux session '$SESSION' ($mode)"
echo "  attach: tmux attach -t $SESSION     detach: Ctrl-b d     stop: $HERE/robot_down.sh"

# ---- 4. tethered: put the human in front of it ----------------------------
if [ "$mode" = tethered ] && [ -t 0 ] && [ -t 1 ]; then
    tmux select-pane -t "${teleop_pane:-$broker_pane}"
    if [ -n "${TMUX:-}" ]; then exec tmux switch-client -t "=$SESSION"; fi
    exec tmux attach -t "=$SESSION"
fi
