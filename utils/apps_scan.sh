#!/usr/bin/env bash
# Shared logic for scanning .desktop apps + flatpaks.
# Outputs: "Name<TAB>Exec" per line (no icon).

apps_scan_generate() {
  local dirs="$1"
  local terminal="${2:-${FZFLAUNCHER_TERMINAL:-kitty}}"

  # Split colon-separated dirs into an array
  local IFS=':'
  local dir
  local -a dir_array=()
  read -ra dir_array <<<"$dirs"

  {
    # .desktop files
    for dir in "${dir_array[@]}"; do
      [[ -d "$dir" ]] || continue
      find -L "$dir" -maxdepth 1 -type f -name "*.desktop"
    done \
    | while IFS= read -r desk; do
        local id name exec is_term
        id="$(basename "$desk" .desktop)"

        name="$(grep -m1 -E '^Name=' "$desk" | sed 's/^Name=//' || true)"
        [[ -z "$name" ]] && name="$id"

        exec="$(grep -m1 -E '^Exec=' "$desk" | sed 's/^Exec=//' || true)"
        # Strip common % tokens
        exec="$(printf '%s' "$exec" | sed -E 's/ *%[fFuUdDnNickvm]//g')"

        is_term="$(grep -m1 -E '^Terminal=' "$desk" | sed 's/^Terminal=//' || false)"
        [[ $is_term == "true" ]] && exec="$terminal -e $exec"

        printf '%s\t%s\n' "$name" "$exec"
      done

    # Flatpak apps, if available
    if have flatpak; then
      flatpak list --app --columns=name,application \
        | tail -n +1 \
        | while IFS=$'\t' read -r name appid; do
            printf '%s\tflatpak run %s\n' "$name" "$appid"
          done
    fi
  } | awk -F'\t' '!seen[$2]++'
}
