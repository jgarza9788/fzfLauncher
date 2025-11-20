#!/usr/bin/env bash
##
# apps_entries: collect .desktop files and flatpaks, and generate commands to launch them.
# Optionally uses a cache file to speed up subsequent runs.

apps_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['apps.icon']}"

  if [[ -f "$FZFLAUNCHER_APP_CACHE" && "$FZFLAUNCHER_USE_APP_CACHE" == "true" ]]; then
    # Use cached format "<name>\t<exec>" (without icon); just prepend icon.
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
    done <"$FZFLAUNCHER_APP_CACHE"
  else
    log "no app_cache"

    # Find .desktop files in the configured app dirs.
    for d in ${FZFLAUNCHER_APP_DIRS//:/ }; do
      [[ -d "$d" ]] && find -L "$d" -maxdepth 1 -type f -name "*.desktop"
    done \
      | while IFS= read -r desk; do
          local id name exec
          id="$(basename "$desk" .desktop)"
          name="$(grep -m1 -E '^Name=' "$desk" | sed 's/^Name=//' || true)"
          [[ -z "$name" ]] && name="$id"

          exec="$(grep -m1 -E '^Exec=' "$desk" | sed 's/^Exec=//' || true)"
          # Strip desktop file placeholders like %f, %u, etc.
          exec="$(printf '%s' "$exec" | sed -E 's/ *%[fFuUdDnNickvm]//g')"

          printf "%s %s\t%s\n" "$icon" "$name" "$exec"
        done \
      | awk -F'\t' '!seen[$2]++'

    # Also include Flatpak apps if flatpak is installed.
    if have flatpak; then
      flatpak list --app --columns=name,application \
        | tail -n +1 \
        | while IFS=$'\t' read -r name appid; do
            printf "%s %s\tflatpak run %s\n" "$icon" "$name" "$appid"
          done \
        | awk -F'\t' '!seen[$2]++'
    fi
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "apps_entries exec-time ${diff_ns}ns"
}

# Populate the app cache asynchronously if caching is enabled. This runs
# immediately when the file is sourced (mirroring the original behaviour).
if [[ "$FZFLAUNCHER_USE_APP_CACHE" == "true" ]]; then
  SET_APP_CACHE="$HOME/.config/fzfLauncher/set_app_cache.sh"
  app_run "$SET_APP_CACHE \"$FZFLAUNCHER_APP_DIRS\" \"$FZFLAUNCHER_APP_CACHE\""
fi
