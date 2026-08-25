#!/system/bin/sh

LOG_FILE="/data/local/tmp/axeron_watchdog.log"
exec >> "$LOG_FILE" 2>&1

CHECK_INTERVAL=10           # 检查间隔（秒）
MAX_FORCE_STOP_PER_CYCLE=3      # 每个“重启→强杀”周期内最大强杀次数
FORCE_STOP_COOLDOWN=60      # 强杀冷却时间（秒），超过此时间重置计数
LAST_FORCE_STOP_TIME=0      # 上次强杀的时间戳
FORCE_STOP_COUNT=0          # 当前周期内的强杀次数


while true; do
    sleep $CHECK_INTERVAL

    if ! pidof axeron_server > /dev/null 2>&1; then
        echo "[$(date)] axeron_server is dead, attempting restart..."

        if [ ! -f "$AXERONLIB/libaxeron.so" ] || [ ! -x "$AXERONLIB/libaxeron.so" ]; then
            echo "[$(date)] ERROR: libaxeron.so not found or not executable at $AXERONLIB"
            continue
        fi

        "$AXERONLIB/libaxeron.so" &
        RESTART_PID=$!
        echo "[$(date)] Started libaxeron.so with PID $RESTART_PID"
        sleep 3
        if pidof axeron_server > /dev/null 2>&1; then
            echo "[$(date)] Restart successful."

            NOW=$(date +%s)
            if [ $((NOW - LAST_FORCE_STOP_TIME)) -ge $FORCE_STOP_COOLDOWN ]; then
                FORCE_STOP_COUNT=0
            fi

            if [ $FORCE_STOP_COUNT -lt $MAX_FORCE_STOP_PER_CYCLE ]; then
                echo "[$(date)] Force-stopping manager (attempt $((FORCE_STOP_COUNT+1))/$MAX_FORCE_STOP_PER_CYCLE)"
                cmd activity force-stop com.frb.axmanager
                FORCE_STOP_COUNT=$((FORCE_STOP_COUNT + 1))
                LAST_FORCE_STOP_TIME=$NOW
            else
                echo "[$(date)] Skipping force-stop: reached max attempts ($MAX_FORCE_STOP_PER_CYCLE) in current cooldown window."
            fi
        else
            echo "[$(date)] WARNING: Restart may have failed (axeron_server still not found after 3s)."
        fi
    else
        if [ $FORCE_STOP_COUNT -gt 0 ]; then
            FORCE_STOP_COUNT=$((FORCE_STOP_COUNT - 1))
        fi
    fi
done