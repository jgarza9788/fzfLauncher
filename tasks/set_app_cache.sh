#!/usr/bin/env bash
set -euo pipefail

dirs="$1"
app_cache="$2"
terminal="${3:-${FZFLAUNCHER_TERMINAL:-kitty}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared utils
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils/helpers.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils/apps_scan.sh"


if (( $(date +%s) - $(stat -c %Y "$app_cache.temp") > 5 )); then
  echo "File is older than 5 seconds"
  rm "$app_cache.temp"
fi

# Avoid stomping over an in-progress write
if [[ -e "$app_cache.temp" ]]; then
  echo "app_cache.temp exists, exit for now"
  exit 0
fi

# Generate into temp file: "Name<TAB>Exec"
apps_scan_generate "$dirs" "$terminal" > "$app_cache.temp"

# Small delay to avoid races with readers (optional, but you had this before)
#sleep 0.5
sleep 30

# Atomic-ish update
mv "$app_cache.temp" "$app_cache"

echo "app cache done"
