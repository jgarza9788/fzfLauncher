# entries/clipboard_entries.sh


clipboard_entries() {
  local start_ns end_ns diff_ns count=0
  start_ns=$(date +%s%N)

  local icon="${PARTS['clipboard.icon']}"
  local limit="${FZFLAUNCHER_CLIPBOARD_LIMIT:-100}"

  # end short ...for speed
  if [[ "$limit" == "0" ]]; then
    return 
  fi

  if have cliphist; then
    # Use cliphist list for display text; do NOT decode here.
    cliphist list | tr -d '\0' | head -n "$limit" \
      | while IFS= read -r token; do
          local display esc_token

          # Clean up the token for display (collapse whitespace, limit length)
          display="$(
            printf '%s' "$token" \
              | tr '\n\r\t' ' ' \
              | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
              | head -c 200
          )"

          # Escape the token so we can safely pass it to a shell command later
          esc_token="$(printf '%q' "$token")"

          # Command: when selected, decode that token and copy it back to clipboard
          printf "%s %s\tprintf %%s %s | cliphist decode | wl-copy\n" \
            "$icon" "$display" "$esc_token"
          ((count++))
        done

  elif command -v wl-paste-history >/dev/null 2>&1; then
    wl-paste-history list \
      | head -n "$limit" \
      | tac \
      | while IFS= read -r content; do
          local display esc_payload

          display="$(
            printf '%s' "$content" \
              | tr '\n\r\t' ' ' \
              | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
              | head -c 200
          )"
          esc_payload="$(printf '%q' "$content")"
          printf "%s %s\tprintf %%s %s | wl-copy\n" "$icon" "$display" "$esc_payload"
          ((count++))
        done

  elif have xclip; then
    local content display esc_payload

    content="$(xclip -selection clipboard -o 2>/dev/null || true)"
    content="$(printf "%s" "$content" | head -n "$limit" | tac)"

    [[ -n "$content" ]] && {
      display="$(
        printf '%s' "$content" \
          | tr '\n\r\t' ' ' \
          | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
          | head -c 200
      )"

      esc_payload="$(printf '%q' "$content")"

      printf "%s %s\tprintf %%s %s | xclip -selection clipboard -in\n" \
        "$icon" "$display" "$esc_payload"
      ((count++))
    }
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "clipboard_entries exec-time ${diff_ns}ns"
  log "clipboard_entries count $count"
}
