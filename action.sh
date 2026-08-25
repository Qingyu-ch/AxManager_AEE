#!/system/bin/sh
#![standalone]

PLUGINS_DIR="$AXERONDIR/plugins"
LOG="/data/local/tmp/axopen_aee.log"
: > "$LOG"

log() { echo "[$(date)] $*" >> "$LOG"; }
log "AXERONDIR=$AXERONDIR"
log "PLUGINS_DIR=$PLUGINS_DIR"

for plugin_dir in "$PLUGINS_DIR"/*/; do
    [ -d "$plugin_dir" ] || continue
    touch "${plugin_dir}disable"
    plugin_id=$(grep "^id=" "${plugin_dir}module.prop" 2>/dev/null | cut -d'=' -f2)
    log "Disabled: $plugin_id"
done

PIDS=""
add_pids() {
    for pattern in "$@"; do
        p=$(pgrep -f "$pattern" 2>/dev/null)
        if [ -n "$p" ]; then
            log "pgrep hit [$pattern]: $p"
            PIDS="$PIDS $p"
        fi
    done
}

add_pids "$PLUGINS_DIR" "axeron" "libaxeron" "service\.sh" "action\.sh"
add_pids "axeron_server" "axmanager" "frb.axmanager" "igniter" "axeron_immune"

if [ -n "$PIDS" ]; then
    PIDS=$(echo $PIDS | tr ' ' '\n' | sort -u | tr '\n' ' ')
    log "Final PID list to kill: $PIDS"
else
    log "No matching background processes found."
fi

if [ -n "$PIDS" ]; then
    for pid in $PIDS; do
        kill -TERM "$pid" 2>/dev/null
    done
    sleep 1
    for pid in $PIDS; do
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
            log "KILL pid=$pid"
        fi
    done
fi

log "=== Kill all done ==="
if pidof axeron_server >/dev/null 2>&1; then
    kill -KILL $(pidof axeron_server) 2>/dev/null
    log "Killed axeron_server"
else
    log "axeron_server not running."
fi

sleep 1
remaining=$(pidof axeron_server 2>/dev/null)
if [ -n "$remaining" ]; then
    log "WARNING: axeron_server still alive: $remaining"
else
    log "Confirmed: axeron_server stopped."
fi