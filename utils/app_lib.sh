#!/usr/bin/env bash
# generate_app_entries: enumerates desktop and Flatpak apps
# Usage: generate_app_entries <colon-separated directories> [include_flatpak]
# It outputs tab-separated <name>\t<exec> lines
generate_app_entries() {
  local dirs_string="$1"
  local include_flatpak="${2:-true}"

  # Split colon-separated directories
  IFS=':' read -ra dirs <<< "$dirs_string"
  # Loop through each directory and extract desktop entries
  for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      while IFS= read -r -d '' desktop; do
        # Extract Name and Exec fields
        local name
        local exec_cmd
        name=$(awk -F= '$1 == "Name" { print $2; exit }' "$desktop")
        exec_cmd=$(awk -F= '$1 == "Exec" { print $2; exit }' "$desktop")
        # Trim Exec to remove placeholder arguments
        exec_cmd=${exec_cmd%% %*}
        # Only output if name is non-empty
        if [[ -n "$name" ]]; then
          printf "%s\t%s\n" "$name" "$exec_cmd"
        fi
      done < <(find "$dir" -maxdepth 1 -name '*.desktop' -print0)
    fi
  done

  # Include Flatpak apps if requested and available
  if [[ "$include_flatpak" == "true" ]] && command -v flatpak &> /dev/null; then
    flatpak list --app --columns=application,description | sed '1d' | while IFS=$'\t' read -r app desc; do
      IFS='.' read -ra parts <<< "$app"
      local name="${parts[1]}"
      local exec_cmd="flatpak run $app"
      printf "%s\t%s\n" "$name" "$exec_cmd"
    done
  fi
}
