#!/usr/bin/env bash
#
# web_entries: wrapper for deprecated_web_entries
web_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  deprecated_web_entries

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "web_entries exec-time ${diff_ns}ns"
}
