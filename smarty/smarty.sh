#!/usr/bin/env bash
#
# smarty.sh -- Smarty's cheat sheet, turned into one tmux session.
#
#   cp smarty.conf.example smarty.conf     # then edit hosts + commands
#   ./smarty.sh mapping                    # SLAM / mapping profile
#   ./smarty.sh navigation                 # localisation + Nav2 profile
#   ./smarty.sh stop                       # stop every pane
#   ./smarty.sh status                     # what is running?
#
# Options:
#   --no-wait     don't wait for ROS topics between stages
#   --headless    don't start teleop / map-saver, don't attach
#   --dry-run     print what would run, change nothing
#
# The point is not that these exact ROS commands are universal. It is the
# shape: one window per host, one pane per process, a real readiness check
# between stages, and a pane that stays open when something crashes.
#
# Run this ON THE ROBOT if you want the processes to survive a wifi drop.
# Run it on the workstation to organise the remote SSH views (the processes
# still die if the link drops -- see README.md).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${SMARTY_CONF:-$HERE/smarty.conf}"
if [ -f "$CONF" ]; then
    # shellcheck disable=SC1090
    source "$CONF"
else
    echo "note: $CONF not found; using smarty.conf.example defaults" >&2
    # shellcheck disable=SC1091
    source "$HERE/smarty.conf.example"
fi

SESSION="${SESSION:-smarty}"
RUN_DIR="${TMPDIR:-/tmp}/smarty-$SESSION"
PROFILE=""
WAIT=1
HEADLESS=0
DRY=0

for arg in "$@"; do
    case "$arg" in
        mapping|navigation) PROFILE="$arg" ;;
        stop|status)        PROFILE="$arg" ;;
        --no-wait)          WAIT=0 ;;
        --headless)         HEADLESS=1 ;;
        --dry-run)          DRY=1 ;;
        -h|--help)          sed -n '2,26p' "$0"; exit 0 ;;
        *) echo "unknown argument: $arg (try --help)" >&2; exit 2 ;;
    esac
done
PROFILE="${PROFILE:-mapping}"

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------
say() { printf '%s\n' "$*"; }
would() { [ "$DRY" = 1 ] && printf '  would run: %s\n' "$*"; }

# make_pane WINDOW NAME STYLE HOST COMMAND
#   STYLE: local | remote | shell
#   HOST : ignored for local/shell
# Prints the new pane id (unless --dry-run).
make_pane() {
    local win="$1" name="$2" style="$3" host="$4" cmd="$5"
    local dir="$RUN_DIR/$win/$name"
    local cmd_file="$dir/cmd.sh" wrapper="$dir/pane.sh" rc="$dir/rc"

    mkdir -p "$dir"

    case "$style" in
        local)
            cat > "$cmd_file" <<EOF
$LOCAL_ROS_SETUP
cd $(printf '%q' "$LOCAL_WS") 2>/dev/null || true
$cmd
EOF
            ;;
        remote)
            local remote_script b64 remote_cmd
            remote_script=$(cat <<EOF
$ROS_SETUP
$cmd
ec=\$?
printf '\\n[$name] remote command exited (status %s)\\n' "\$ec"
printf '[$name] You are still on $host. Up-arrow may have the command.\\n\\n'
EOF
)
            # ssh joins its arguments with spaces and lets the *remote* shell
            # re-parse them, so quoting a multi-line script is a trap. Send it
            # base64-encoded instead: no quoting rules survive the trip.
            b64=$(printf '%s' "$remote_script" | base64 | tr -d '\n')
            remote_cmd="echo $b64 | base64 -d | bash; exec bash -l"
            printf 'ssh -t -o ServerAliveInterval=15 -o ServerAliveCountMax=3 %q %q\n' \
                "$host" "$remote_cmd" > "$cmd_file"
            ;;
        shell)
            : > "$cmd_file"
            ;;
        *)
            echo "make_pane: bad style '$style'" >&2; exit 2 ;;
    esac

    {
        echo '[ -f ~/.bashrc ] && source ~/.bashrc'
        printf 'history -s %q\n' "$cmd"
        printf "PS1='[%s] \\$ '\n" "$name"
    } > "$rc"

    if [ "$style" = shell ]; then
        printf '#!/usr/bin/env bash\nexport BASH_SILENCE_DEPRECATION_WARNING=1\ncd %q\nexec bash --rcfile %q\n' \
            "$HERE" "$rc" > "$wrapper"
    else
        printf '#!/usr/bin/env bash\nexport BASH_SILENCE_DEPRECATION_WARNING=1\ncd %q\nbash %q\nec=$?\nprintf "\\n[%s] exited (status %%s) -- pane kept open\\n" "$ec"\nprintf "[%s] Up-arrow + Enter re-runs it.\\n\\n"\nexec bash --rcfile %q\n' \
            "$HERE" "$cmd_file" "$name" "$name" "$rc" > "$wrapper"
    fi
    chmod +x "$wrapper"

    if [ "$DRY" = 1 ]; then
        printf '  %-9s %-11s %s\n' "$win" "$name" "$style ${host:+@$host} $cmd" >&2
        return 0
    fi

    local pane
    if ! tmux has-session -t "=$SESSION" 2>/dev/null; then
        pane=$(tmux new-session -d -s "$SESSION" -n "$win" -c "$HERE" -x 220 -y 55 \
            -P -F '#{pane_id}' "bash $(printf '%q' "$wrapper")")
    elif tmux list-windows -t "=$SESSION" -F '#{window_name}' | grep -qx "$win"; then
        pane=$(tmux split-window -t "$SESSION:$win" -c "$HERE" -P -F '#{pane_id}' \
            "bash $(printf '%q' "$wrapper")")
    else
        pane=$(tmux new-window -t "$SESSION" -n "$win" -c "$HERE" -P -F '#{pane_id}' \
            "bash $(printf '%q' "$wrapper")")
    fi
    tmux select-pane -t "$pane" -T "$name"
    tmux select-layout -t "$SESSION:$win" tiled
    printf '%s' "$pane"
}

set_session_options() {
    [ "$DRY" = 1 ] && return 0
    tmux set-option -t "$SESSION" mouse on
    tmux set-option -t "$SESSION" history-limit 50000
    tmux set-option -t "$SESSION" status-left ' #[bold]smarty '
    tmux set-option -w -t "$SESSION:" pane-border-status top
    tmux set-option -w -t "$SESSION:" pane-border-format ' #{pane_index} · #{pane_title} '
}

# wait_topic HOST TOPIC -- HOST="local" or an ssh host. Warns, never aborts.
wait_topic() {
    local host="$1" topic="$2" timeout="${3:-25}"
    [ "$WAIT" = 1 ] || return 0
    if [ "$DRY" = 1 ]; then printf '  would wait for %s on %s\n' "$topic" "$host" >&2; return 0; fi
    printf '  waiting for %s on %s (max %ss) ... ' "$topic" "$host" "$timeout"
    local i ok=0
    for i in $(seq 1 "$timeout"); do
        if [ "$host" = local ]; then
            if bash -lc "$LOCAL_ROS_SETUP; ros2 topic list 2>/dev/null | grep -qx '$topic'"; then ok=1; break; fi
        else
            if ssh -o ConnectTimeout=5 "$host" \
                "bash -lc $(printf '%q' "$ROS_SETUP; ros2 topic list 2>/dev/null | grep -qx '$topic'")"; then
                ok=1; break
            fi
        fi
        sleep 1
    done
    if [ "$ok" = 1 ]; then echo "ok"; else echo "not seen (continuing)"; fi
}

# ---------------------------------------------------------------------------
# stop / status
# ---------------------------------------------------------------------------
if [ "$PROFILE" = stop ]; then
    if ! tmux has-session -t "=$SESSION" 2>/dev/null; then
        echo "session '$SESSION' is not running"; exit 0
    fi
    for pane in $(tmux list-panes -s -t "=$SESSION" -F '#{pane_index}' | sort -rn); do
        tmux send-keys -t "$SESSION:.$pane" C-c 2>/dev/null || true
        sleep 0.1
    done
    sleep 0.7
    tmux kill-session -t "=$SESSION"
    rm -rf "$RUN_DIR"
    echo "stopped '$SESSION'"
    exit 0
fi

if [ "$PROFILE" = status ]; then
    if ! tmux has-session -t "=$SESSION" 2>/dev/null; then
        echo "session '$SESSION' is not running"; exit 0
    fi
    tmux list-panes -s -t "=$SESSION" -F '#{window_name}/#{pane_title}  #{pane_current_command}' | sort
    exit 0
fi

# ---------------------------------------------------------------------------
# launch
# ---------------------------------------------------------------------------
rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

say "profile: $PROFILE    session: $SESSION    mode: $([ "$HEADLESS" = 1 ] && echo headless || echo tethered)"
[ "$DRY" = 1 ] && say "(dry run -- nothing will be started)"

# ---- 1. robot: base + lidar, on the robot itself --------------------------
make_pane robot base  remote "$ROBOT_HOST" "$CMD_BASE" >/dev/null
make_pane robot lidar remote "$ROBOT_HOST" "$CMD_LIDAR" >/dev/null
set_session_options
wait_topic "$ROBOT_HOST" /scan

# ---- 2. sensors: camera and the talker on their own hosts -----------------
make_pane sensors camera remote "$CAMERA_HOST" "$CMD_CAMERA" >/dev/null
make_pane sensors talker remote "$ATLAS_HOST" "$CMD_TALKER" >/dev/null
wait_topic "$CAMERA_HOST" /image_raw

# ---- 3. SLAM or localisation, on the workstation --------------------------
if [ "$PROFILE" = mapping ]; then
    make_pane slam display  local "" "$CMD_DISPLAY" >/dev/null
    make_pane slam toolbox  local "" "$CMD_SLAM_MAPPING" >/dev/null
    make_pane slam turtlebot local "" "$CMD_SLAM_TURTLEBOT" >/dev/null
    make_pane slam rviz     local "" "$CMD_RVIZ" >/dev/null
else
    make_pane nav display     local "" "$CMD_DISPLAY" >/dev/null
    make_pane nav localization local "" "$CMD_LOCALIZATION" >/dev/null
    wait_topic local /map 30
    make_pane nav nav2        local "" "$CMD_NAV2" >/dev/null
    make_pane nav rviz        local "" "$CMD_RVIZ" >/dev/null
fi

# ---- 4. the human bits ----------------------------------------------------
if [ "$HEADLESS" = 0 ]; then
    make_pane drive teleop local "" "$CMD_TELEOP" >/dev/null
    if [ "$PROFILE" = mapping ]; then
        # Not started: press Up-arrow when you are done driving the map.
        make_pane drive map-saver local "" "$CMD_MAP_SAVE" >/dev/null
    fi
fi

if [ "$DRY" = 1 ]; then
    say "dry run complete."
    exit 0
fi

say
tmux list-windows -t "=$SESSION" -F '  #{window_index}: #{window_name} (#{window_panes} panes)'
say
say "  attach: tmux attach -t $SESSION    detach: Ctrl-b d"
say "  stop:   $HERE/smarty.sh stop"

if [ "$HEADLESS" = 0 ] && [ -t 0 ] && [ -t 1 ]; then
    tmux select-window -t "$SESSION:robot"
    if [ -n "${TMUX:-}" ]; then exec tmux switch-client -t "=$SESSION"; fi
    exec tmux attach -t "=$SESSION"
fi
