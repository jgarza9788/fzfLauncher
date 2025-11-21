# utils/logging.sh
# Shared logging functions for fzfLauncher.

LOGFILE="${LOGFILE:-$HOME/.config/fzfLauncher/log.txt}"
MAX_LINES="${MAX_LINES:-1000}"

mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

log() {
  if [[ "${FZFLAUNCHER_LOG_ENABLE:-true}" == "false" ]]; then
    return 0
  fi

  local msg="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s | %s\n' "$timestamp" "$msg" >>"$LOGFILE"
}

log_truncate() {
  local lines
  lines=$(wc -l <"$LOGFILE")
  if (( lines > MAX_LINES )); then
    tail -n "$MAX_LINES" "$LOGFILE" >"$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  fi
}
