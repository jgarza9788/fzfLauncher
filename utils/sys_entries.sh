#!/usr/bin/env bash

sys_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  # Use the deprecated sys_entries function from the main script.
  deprecated_sys_entries

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "sys_entries exec-time ${diff_ns}ns"
}
