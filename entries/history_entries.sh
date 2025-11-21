# entries/history_entries.sh

hist_fish() {
  local icon="${PARTS['history.icon']}"
  local f="$HOME/.local/share/fish/fish_history"
  [[ -r "$f" ]] || return 0

  tac "$f" \
    | awk '$1=="-" && $2=="cmd:" { sub(/^- cmd: /,""); print }' \
    | awk 'NF' \
    | sed 's/^[ \t]\+//;s/[ \t]\+$//' \
    | awk 'seen[$0]++==0 {print}' \
    | head -n "${HIST_LIMIT:-500}" \
    | while IFS= read -r c; do
        printf "%s [fish] %s\t%s\n" "$icon" "$c" "$c"
      done
}

hist_bash() {
  local icon="${PARTS['history.icon']}"
  local f="$HOME/.bash_history"
  [[ -r "$f" ]] || return 0

  awk '/^#/ {next} {print}' "$f" \
    | awk 'NF' \
    | sed 's/^[ \t]\+//;s/[ \t]\+$//' \
    | tac \
    | awk 'seen[$0]++==0 {print}' \
    | head -n "${HIST_LIMIT:-500}" \
    | while IFS= read -r c; do
        printf "%s [bash] %s\t%s\n" "$icon" "$c" "$c"
      done
}

hist_zsh() {
  local icon="${PARTS['history.icon']}"
  local f="$HOME/.zsh_history"
  [[ -r "$f" ]] || return 0

  awk -F';' '
    /^: [0-9]+:[0-9]+;/{sub(/^: [0-9]+:[0-9]+;/,"");print}
    !/^: [0-9]+:[0-9]+;/{print}
  ' "$f" \
    | awk 'NF' \
    | sed 's/^[ \t]\+//;s/[ \t]\+$//' \
    | tac \
    | awk 'seen[$0]++==0 {print}' \
    | head -n "${HIST_LIMIT:-500}" \
    | while IFS= read -r c; do
        printf "%s [zsh] %s\t%s\n" "$icon" "$c" "$c"
      done
}

history_entries() {
  local start_ns end_ns diff_ns
  local count=0
  start_ns=$(date +%s%N)

  local limit="${HIST_LIMIT:-500}"

  if [[ "$limit" -gt 0 ]]; then
    while IFS= read -r line; do
      printf "%s\n" "$line"
      ((count++))
    done < <(
      hist_fish
      hist_zsh
      hist_bash
    )
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))

  log "hist_entries exec-time ${diff_ns}ns"
  log "hist_entries count $count"
}