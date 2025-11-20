#!/usr/bin/env bash
##
# windows_entries: list active Niri windows with commands to focus or jump to them.

windows_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['windows.icon']}"

  # Choose the correct switch command for focusing a window.
  local switch_cmd="niri msg action focus-window --id"
  if $FZFLAUNCHER_NIRI_JUMP; then
    switch_cmd="$HOME/.config/fzfLauncher/niri_jump.sh"
  fi

  # If niri is not available, nothing to output.
  if ! have niri; then
    return 0
  fi

  if have jq; then
    # JSON IPC path: parse windows and build label + command lines.
    niri msg --json windows \
      | jq -r --arg icon "$icon" --arg switch_cmd "$switch_cmd" '
          .[] |
          (.id                                // empty)        as $id |
          (.title                             // "(untitled)") as $t  |
          (.app_id                            // "-")          as $a  |
          (.workspace_id                      // "-")          as $w  |
          (.layout.pos_in_scrolling_layout[0] // "-")          as $c  |
          ($t | tostring | gsub("\\s+"; " "))  as $ts |
          ($a | tostring | gsub("\\s+"; " "))  as $as |
          "\($icon) [\($w)|\($c)] \($ts) — \($as)\t \($switch_cmd) \($id)"
        '
  else
    # Fallback: parse human-readable "niri msg windows" output with awk.
    niri msg windows 2>/dev/null | awk -v icon="$icon" -v switch_cmd="$switch_cmd" '
      /^[[:space:]]*Window ID/ {
          id=$3; gsub(/:/, "", id)
      }
      /^[[:space:]]*Title:/ {
          sub(/^[[:space:]]*Title:[[:space:]]*/, "", $0)
          t=$0
      }
      /^[[:space:]]*App ID:/ {
          sub(/^[[:space:]]*App ID:[[:space:]]*/, "", $0)
          a=$0
      }
      /^[[:space:]]*Workspace ID:/ {
          w=$3; gsub(/:/, "", w)

          gsub(/[ \t\r\n]+/, " ", t)
          gsub(/[ \t\r\n]+/, " ", a)

          printf "%s [%s] %s — %s\t %s %s\n",
                icon, w, t, a, switch_cmd, id
      }
    '
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "windows_entries exec-time ${diff_ns}ns"
}
