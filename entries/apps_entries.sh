# entries/apps_entries.sh

apps_entries() {
  local start_ns end_ns diff_ns count=0
  start_ns=$(date +%s%N)

  local icon="${PARTS['apps.icon']}"
  local cache="${FZFLAUNCHER_APP_CACHE:-$HOME/.config/fzfLauncher/cache/app_cache}"

  if [[ -f "$cache" && "${FZFLAUNCHER_USE_APP_CACHE:-true}" == "true" ]]; then
    # Use cached list: lines are "Name<TAB>Exec"
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
      ((count++))
    done <"$cache"
  else
    log "no app_cache"

    # Generate fresh list via shared helper: "Name<TAB>Exec"
    apps_scan_generate "$FZFLAUNCHER_APP_DIRS" "$FZFLAUNCHER_TERMINAL" \
      | while IFS= read -r line; do
          printf '%s %s\n' "$icon" "$line"
          ((count++))
        done
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "apps_entries exec-time ${diff_ns}ns"
  log "apps_entries count $count"
}

# Trigger async app cache update (same behavior as before).
if [[ "${FZFLAUNCHER_USE_APP_CACHE:-true}" == "true" ]]; then
  log "running set_app_cache,sh"
  # set_app_cache.sh lives next to fzfLauncher.sh
  SET_APP_CACHE="$SCRIPT_DIR/tasks/set_app_cache.sh"
  app_run "$SET_APP_CACHE \"$FZFLAUNCHER_APP_DIRS\" \"$FZFLAUNCHER_APP_CACHE\" \"$FZFLAUNCHER_TERMINAL\""
fi
