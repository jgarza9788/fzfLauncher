#!/usr/bin/env bash
#
# history_entries: aggregate shell history from fish, zsh, and bash via deprecated functions.
history_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  {
    deprecated_hist_fish
    deprecated_hist_zsh
    deprecated_hist_bash
  }

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "hist_entries exec-time ${diff_ns}ns"
}
