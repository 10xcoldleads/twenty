#!/bin/sh
set -eu

LOG_FILE="${TWENTY_UPGRADE_LOG_FILE:-/tmp/twenty-upgrade.log}"
PID_FILE="${TWENTY_UPGRADE_PID_FILE:-/tmp/twenty-upgrade.pid}"
LOG_MAX_BYTES="${TWENTY_UPGRADE_LOG_MAX_BYTES:-52428800}"
CAP_FILE="$LOG_FILE.cap"
CAP_MARKER="--- log capped to $LOG_MAX_BYTES bytes, earlier output dropped, this line is truncated: "
CAP_EVERY_SECONDS=1
TAIL_LINES=20
SELF="$0"
export LOG_FILE PID_FILE SELF

upgrade_pid() { [ -s "$PID_FILE" ] && cat "$PID_FILE" || return 1; }
stream()      { exec tail -f "$LOG_FILE"; }
log_size()    { stat -c %s "$LOG_FILE" 2>/dev/null || wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' '; }

is_our_upgrade() {
  [ -r "/proc/$1/cmdline" ] || return 0
  tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -q 'dist/command/command'
}

is_running() {
  pid=$(upgrade_pid) && kill -0 "$pid" 2>/dev/null && is_our_upgrade "$pid"
}

detach_hint() {
  echo "Ctrl+C detaches the stream only. Use 'yarn upgrade:background:stop' to stop the run."
}

show_tail() {
  [ -f "$LOG_FILE" ] || return 0
  echo "Tail of $LOG_FILE:" >&2
  tail -n "$TAIL_LINES" "$LOG_FILE"
}

last_run() {
  code=$(grep '^EXIT=' "$LOG_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2)
  case "$code" in
    0)   echo "completed" ;;
    130) echo "stopped gracefully on SIGINT — rerun to resume" ;;
    143) echo "stopped gracefully on SIGTERM — rerun to resume" ;;
    137) echo "killed (SIGKILL) — partial work possible, rerun to resume" ;;
    "")  echo "left no exit code — killed, or never started" ;;
    *)   echo "failed (exit $code)" ;;
  esac
}

# Started by start() next to the run, never called by hand. Keeps the log under
# the cap by truncating it in place: the run holds an O_APPEND fd on this inode,
# so a rotation would leave it writing to the file we moved aside, and O_APPEND
# writers resume at the new EOF, so shrinking leaves no sparse hole.
cap() {
  run_pid=$1
  [ "$LOG_MAX_BYTES" -gt 0 ] || return 0
  keep=$((LOG_MAX_BYTES / 2))

  # A trap runs between commands only, so a rewrite in progress always finishes
  # before this exits, and nothing survives to race the EXIT= line.
  trap 'exit 0' TERM INT

  # is_our_upgrade also rules out a zombie, whose cmdline reads empty: PID 1 in
  # the pod never reaps, so kill -0 alone would keep this loop alive forever.
  while kill -0 "$run_pid" 2>/dev/null && is_our_upgrade "$run_pid"; do
    sleep "$CAP_EVERY_SECONDS"
    [ -f "$LOG_FILE" ] || continue
    size=$(log_size)
    [ "${size:-0}" -gt "$LOG_MAX_BYTES" ] || continue

    tail -c "$keep" "$LOG_FILE" > "$CAP_FILE" || continue
    { printf '%s' "$CAP_MARKER"; cat "$CAP_FILE"; } > "$LOG_FILE"
    rm -f "$CAP_FILE"
  done
}

start() {
  case "$LOG_MAX_BYTES" in
    '' | *[!0-9]*)
      echo "Failed to start: TWENTY_UPGRADE_LOG_MAX_BYTES must be a whole number of bytes (0 disables the cap)" >&2
      exit 1 ;;
  esac

  command -v setsid > /dev/null || {
    echo "Failed to start: setsid not found, cannot detach the run from this terminal" >&2
    echo "Use 'yarn command:prod upgrade' to run it in the foreground instead." >&2
    exit 1
  }

  if is_running; then
    echo "Failed to start: already running (pid $(upgrade_pid))" >&2; exit 1
  fi
  : > "$LOG_FILE"; rm -f "$PID_FILE" "$CAP_FILE"

  # Not exec: the wrapper has to outlive node to record EXIT=, and stop has to
  # signal node alone, never the process group this would otherwise share.
  # node stays out of any pipeline so $! names it, and the capper is stopped and
  # reaped before EXIT= is written so a cap can never eat that line.
  setsid sh -c '
    node dist/command/command upgrade "$@" &
    run_pid=$!
    echo $run_pid > "$PID_FILE"
    sh "$SELF" cap $run_pid &
    cap_pid=$!
    wait $run_pid
    code=$?
    kill -TERM $cap_pid 2>/dev/null
    wait $cap_pid 2>/dev/null
    echo "EXIT=$code"
  ' upgrade-background "$@" < /dev/null >> "$LOG_FILE" 2>&1 &

  i=0
  while [ ! -s "$PID_FILE" ] && [ "$i" -lt 10 ]; do i=$((i + 1)); sleep 1; done
  is_running || {
    echo "Failed to start: see $LOG_FILE" >&2
    tail -n "$TAIL_LINES" "$LOG_FILE" >&2
    exit 1
  }

  echo "Running (pid $(upgrade_pid)), logging to $LOG_FILE"
  detach_hint
  stream
}

logs() {
  if is_running; then
    echo "Running (pid $(upgrade_pid)), following $LOG_FILE" >&2
    detach_hint >&2
    stream
  fi
  [ -f "$LOG_FILE" ] || { echo "Not running, no log at $LOG_FILE" >&2; exit 1; }
  echo "Not running, last run $(last_run)" >&2
  show_tail
}

stop() {
  is_running || { echo "Not running, nothing to stop" >&2; rm -f "$PID_FILE"; exit 1; }
  pid=$(upgrade_pid)

  case "${1:-}" in
    "")
      kill -TERM "$pid"
      echo "SIGTERM sent to $pid, it finishes the step in progress then stops (exit 143)" >&2
      sleep 1
      show_tail
      echo "Follow with 'yarn upgrade:background:logs'. Still stuck: 'stop --now'. Last resort: 'stop --force'." >&2
      ;;
    --now)
      kill -TERM "$pid"; sleep 2; kill -TERM "$pid" 2>/dev/null || true
      echo "Second SIGTERM sent to $pid, immediate exit with the step in progress left unfinished" >&2
      sleep 1
      show_tail
      ;;
    --force)
      kill -KILL "$pid"
      echo "SIGKILL sent to $pid, no graceful boundary so a multi-transaction command may leave partial work" >&2
      show_tail
      ;;
    *) echo "usage: stop [--now|--force]" >&2; exit 1 ;;
  esac
}

case "${1:-}" in
  start) shift; start "$@" ;;
  logs)  logs ;;
  stop)  shift; stop "$@" ;;
  cap)   shift; cap "$@" ;;
  *) echo "usage: $0 {start [args]|logs|stop [--now|--force]}" >&2; exit 1 ;;
esac
