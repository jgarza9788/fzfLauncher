#!/usr/bin/env bash
#
# cust_entries: user-defined commands loaded from FZFLAUNCHER_CUST_CMD_FILE.
# Each line in that file should be "<label>\t<command>" (or similar).
cust_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['cust.icon']}"

  if [[ -f "$FZFLAUNCHER_CUST_CMD_FILE" ]]; then
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
    done <"$FZFLAUNCHER_CUST_CMD_FILE"
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "cust_entries exec-time ${diff_ns}ns"
}
