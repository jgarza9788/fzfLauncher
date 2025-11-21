windows_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['windows.icon']}"
  local switch_cmd="niri msg action focus-window --id"
  local count=0

  if ${FZFLAUNCHER_NIRI_JUMP:-true}; then
    switch_cmd="$HOME/.config/fzfLauncher/niri_jump.sh"
  fi

  if ! have niri; then
    return 0
  fi

  # -------------------------------
  # JQ VERSION (preferred)
  # -------------------------------
  if have jq; then
    local lines=()
    mapfile -t lines < <(
      niri msg --json windows \
        | jq -r --arg icon "$icon" --arg switch_cmd "$switch_cmd" '
            # normalize fields into a list of objects
            map({
              id: (.id // ""),
              title: (.title // "(untitled)"),
              app: (.app_id // "-"),
              ws: (.workspace_id // 999999),
              pos: (.layout.pos_in_scrolling_layout[0] // -1)  # -1 for floating/unknown
            })
            # sort: pos DESC (via -.pos), workspace ASC
            | sort_by(.ws, .pos)[]
            | (
                $icon + " [" + (.ws|tostring) + "|" + (.pos|tostring) + "] "
                + (.title|tostring|gsub("\\s+";" "))
                + " — "
                + (.app|tostring|gsub("\\s+";" "))
                + "\t" + $switch_cmd + " " + (.id|tostring)
              )
          '
    )

    for line in "${lines[@]}"; do
      printf '%s\n' "$line"
    done

    count=${#lines[@]}

  else
    # -------------------------------
    # FALLBACK (no jq): parse text output from `niri msg windows`
    # Handles tiled + floating windows
    # -------------------------------
    local lines=()
    mapfile -t lines < <(
      niri msg windows 2>/dev/null \
        | awk -v icon="$icon" -v switch_cmd="$switch_cmd" '
          function emit() {
            if (!have_cur) return
            if (pos == "") pos = -1   # floating / unknown -> last
            gsub(/[ \t\r\n]+/, " ", t)
            gsub(/[ \t\r\n]+/, " ", a)

            # Tabs for sorting:
            #   1: -pos (so higher pos first → DESC)
            #   2: workspace (ASC)
            #   3: final rendered line
            printf "%d\t%d\t%s [%d|%d] %s — %s\t %s %s\n",
              -pos, w, icon, w, pos, t, a, switch_cmd, id
          }

          BEGIN {
            have_cur = 0
            id = ""; t = ""; a = ""; w = 0; pos = -1
          }

          /^[[:space:]]*Window ID/ {
            # starting a new window: emit previous, then reset
            if (have_cur) emit()
            have_cur = 1

            id = $3
            gsub(/:/, "", id)

            t = ""
            a = ""
            w = 0
            pos = -1
          }

          /^[[:space:]]*Title:/ {
            sub(/^[[:space:]]*Title:[[:space:]]*/, "", $0)
            t = $0
          }

          /^[[:space:]]*App ID:/ {
            sub(/^[[:space:]]*App ID:[[:space:]]*/, "", $0)
            a = $0
          }

          /^[[:space:]]*Workspace ID:/ {
            w = $3
            gsub(/:/, "", w)
          }

          # Tiled windows:
          /Scrolling position:[[:space:]]*column[[:space:]]*[0-9]+/ {
            match($0, /column[[:space:]]+[0-9]+/)
            if (RSTART > 0) {
              col = substr($0, RSTART, RLENGTH)
              gsub(/[^0-9]/, "", col)
              pos = col + 0
            } else {
              pos = -1
            }
            emit()
            have_cur = 0
          }

          # Floating windows: no column, but have Workspace-view position
          /Workspace-view position:/ {
            # pos stays at default -1, we just emit
            emit()
            have_cur = 0
          }

          END {
            # in case the last block never hit scrolling/workspace-view
            if (have_cur) emit()
          }
        ' \
        | sort -t$'\t' -k2,2n -k1,1n \
        | cut -f3-
    )

    for line in "${lines[@]}"; do
      printf "%s\n" "$line"
    done

    count=${#lines[@]}
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "windows_entries exec-time ${diff_ns}ns"
  log "windows_entries count $count"
}
