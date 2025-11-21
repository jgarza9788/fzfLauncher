# entries/web_entries.sh

web_entries() {
  local start_ns end_ns diff_ns count=0
  start_ns=$(date +%s%N)

  local icon="${PARTS['web.icon']}"
  local web_apps="$HOME/.config/fzfLauncher/data/web_apps"

  if [[ -f "$web_apps" ]]; then
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
      ((count++))
    done <"$web_apps"
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "web_entries exec-time ${diff_ns}ns"
  log "web_entries count $count"
}
