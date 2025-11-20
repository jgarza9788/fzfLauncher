#!/usr/bin/env bash

clipboard_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  # Use the deprecated clipboard_entries function from the main script.
  deprecated_clipboard_entries

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "clipboard_entries exec-time ${diff_ns}ns"
}
