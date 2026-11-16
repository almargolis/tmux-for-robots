#!/usr/bin/env bash
#
# _screen_session.sh -- find and stop GNU screen sessions by name.
#
# Shared by _launch_common.sh, status and stop_all.
#
# Why not `screen -ls | grep -q`? Under `set -o pipefail`, a pipeline fails if
# *any* stage fails. grep -q exits as soon as it matches, screen can take
# SIGPIPE, and the whole pipeline reports failure even though the session was
# found. The result is duplicate sessions that "status" cannot see. Parsing a
# captured string avoids the problem entirely.

# screen_session_pids NAME -> one PID per matching session (may be empty).
screen_session_pids() {
    local name="$1" out line pid rest
    out="$(screen -ls 2>/dev/null || true)"
    while IFS= read -r line; do
        line="${line#$'\t'}"
        case "$line" in
            [0-9]*)
                pid="${line%%.*}"
                rest="${line#*.}"
                case "$rest" in
                    "$name"$'\t'*|"$name "*) printf '%s\n' "$pid" ;;
                esac
                ;;
        esac
    done <<< "$out"
}

screen_has_session() {
    [ -n "$(screen_session_pids "$1")" ]
}

# screen_signal_session NAME [SYMBOL]
#   default SYMBOL is Ctrl-C (\003), so a node can shut down politely.
screen_signal_session() {
    local name="$1" key="${2:-$'\003'}" pid
    for pid in $(screen_session_pids "$name"); do
        screen -S "$pid.$name" -X stuff "$key" 2>/dev/null || true
    done
}

# screen_quit_session NAME -> 0 if at least one session was closed.
screen_quit_session() {
    local name="$1" pid closed=1
    for pid in $(screen_session_pids "$name"); do
        if screen -S "$pid.$name" -X quit 2>/dev/null; then closed=0; fi
    done
    return "$closed"
}
