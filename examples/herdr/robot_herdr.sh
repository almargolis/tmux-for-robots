#!/usr/bin/env bash
#
# robot_herdr.sh -- the same pretend robot, laid out in Herdr instead of tmux.
#
#   ./robot_herdr.sh          create a "robot-sim" workspace and start the nodes
#   ./robot_herdr.sh --stop   close that workspace
#
# Herdr is a terminal workspace manager for AI coding agents. It keeps the
# same client/server model as tmux (panes survive detach and SSH drops), but
# adds a mouse-first UI and an agent-aware sidebar. It also has a CLI and a
# local socket API, which is what this script drives.
#
# After running it:
#   herdr                     attach to the TUI and click the "robot-sim" workspace
#
# Prerequisite: herdr installed (https://herdr.dev). If no server is running,
# this script starts a headless one for you.

set -euo pipefail
LABEL="${LABEL:-robot-sim}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM="$(cd "$HERE/../robot_sim" && pwd)"
PORT="${MINIBUS_PORT:-7777}"

command -v herdr >/dev/null || { echo "herdr is not installed -- see https://herdr.dev" >&2; exit 1; }

jget() {  # jget dotted.path < json
    python3 -c 'import json,sys
d = json.load(sys.stdin)
for key in sys.argv[1].split("."):
    d = d[key]
print(d)' "$1"
}

# Find an existing workspace by label (empty output if none).
find_ws() {
    herdr workspace list | python3 -c 'import json,sys
label = sys.argv[1]
for w in json.load(sys.stdin)["result"]["workspaces"]:
    if w.get("label") == label:
        print(w["workspace_id"])
        break' "$LABEL"
}

if [ "${1:-}" = "--stop" ]; then
    ws="$(find_ws)"
    if [ -n "$ws" ]; then herdr workspace close "$ws" >/dev/null && echo "closed workspace '$LABEL'"; else echo "workspace '$LABEL' is not open"; fi
    exit 0
fi

# ---- server: start a headless one if the TUI is not already running --------
if ! herdr status 2>/dev/null | grep -q 'status: running'; then
    echo "starting a headless Herdr server ..."
    nohup herdr server >/tmp/herdr-server.log 2>&1 &
    for _ in $(seq 1 20); do
        herdr status 2>/dev/null | grep -q 'status: running' && break
        sleep 0.2
    done
fi

# Replace a stale workspace with the same name.
old="$(find_ws || true)"
if [ -n "$old" ]; then herdr workspace close "$old" >/dev/null || true; fi

# ---- create the workspace; the first pane is our broker -------------------
created=$(herdr workspace create --label "$LABEL" --cwd "$SIM" --no-focus \
    --env "MINIBUS_PORT=$PORT")
ws=$(printf '%s' "$created" | jget result.workspace.workspace_id)
broker_pane=$(printf '%s' "$created" | jget result.root_pane.pane_id)
herdr pane rename "$broker_pane" broker >/dev/null 2>&1 || true
herdr pane run "$broker_pane" 'python3 broker.py' >/dev/null

# ---- launch order: wait until the broker accepts connections --------------
echo "waiting for the broker on port $PORT ..."
if ! python3 "$SIM/wait_for_port.py" "$PORT" --timeout 15; then
    echo "broker did not start -- inspect the workspace with: herdr" >&2
    exit 1
fi

# ---- build a 3x2 grid, then run one node in each pane ---------------------
# Splitting the same pane repeatedly makes slivers, so split a balanced tree:
#   broker | lidar  | camera
#   navig  | motors | agent-shell
split() {  # split TARGET right|down [RATIO] -> prints new pane id
    herdr pane split "$1" --direction "$2" --ratio "${3:-0.5}" --cwd "$SIM" --no-focus \
        --env "MINIBUS_PORT=$PORT" | jget result.pane.pane_id
}
camera_pane=$(split "$broker_pane" right 0.667)   # right column: 1/3 width
navigator_pane=$(split "$broker_pane" down)       # bottom-left
shell_pane=$(split "$camera_pane" down)           # bottom-right
lidar_pane=$(split "$broker_pane" right)          # top-middle
motors_pane=$(split "$navigator_pane" right)      # bottom-middle

run_node() {  # run_node PANE NAME COMMAND
    herdr pane rename "$1" "$2" >/dev/null 2>&1 || true
    herdr pane run "$1" "$3" >/dev/null
}

run_node "$lidar_pane"     lidar        'python3 lidar.py'
run_node "$camera_pane"    camera       "python3 camera.py ${CAMERA_ARGS:-}"
run_node "$navigator_pane" navigator    'python3 navigator.py'
run_node "$motors_pane"    motors       'python3 motors.py'
run_node "$shell_pane"     agent-shell  'echo "Spare shell: ask an agent to inspect the robot panes."'

# Remember the pane ids so the agent demo (and your own scripts) can find them
# without reading JSON by hand.
RUN_DIR="${TMPDIR:-/tmp}/herdr-$LABEL"
mkdir -p "$RUN_DIR"
{
    printf 'export HERDR_WORKSPACE=%q\n' "$ws"
    printf 'export BROKER_PANE=%q\n' "$broker_pane"
    printf 'export LIDAR_PANE=%q\n' "$lidar_pane"
    printf 'export CAMERA_PANE=%q\n' "$camera_pane"
    printf 'export NAVIGATOR_PANE=%q\n' "$navigator_pane"
    printf 'export MOTORS_PANE=%q\n' "$motors_pane"
    printf 'export AGENT_PANE=%q\n' "$shell_pane"
} > "$RUN_DIR/panes.env"

echo "created Herdr workspace '$LABEL' (workspace $ws)"
echo "  open the TUI:  herdr"
echo "  pane ids:      source $RUN_DIR/panes.env   (AGENT_PANE=$shell_pane)"
echo "  stop:          $HERE/robot_herdr.sh --stop"
