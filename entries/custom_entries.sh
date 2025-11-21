# entries/custom_entries.sh

cust_entries() {
  local start_ns end_ns diff_ns count=0
  start_ns=$(date +%s%N)

  local icon="${PARTS['cust.icon']}"
  local file="${FZFLAUNCHER_CUST_CMD_FILE:-$HOME/.config/fzfLauncher/data/cust_cmds}"

  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
      ((count++))
    done <"$file"
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "cust_entries exec-time ${diff_ns}ns"
  log "cust_entries count $count"
}
