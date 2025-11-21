#!/usr/bin/env bash
set -euo pipefail

################################################################################
# fzfLauncher (main)
#
# This is the main entry point. It now delegates:
#   - shared helpers to utils/*.sh
#   - mode-specific entry generators to entries/*_entries.sh
################################################################################

# --------------------- CLI DEFAULTS ---------------------

MODE="all"          # windows|apps|history|web|sys|clipboard|custom|all
HIST_LIMIT=500      # shell history items
CLIPBOARD_LIMIT=100 # clipboard entries

# --------------------- HELP TEXT ------------------------

show_help() {
  cat <<EOF
fzfLauncher — Universal Launcher for Niri / Wayland / Linux
------------------------------------------------------------

Usage:
  $0 [OPTIONS]

Options:
  --mode MODE
        Select which menu to show.
        Available:
          windows     Show Niri windows
          apps        Applications (.desktop & flatpak)
          history     Terminal history (fish / zsh / bash)
          web         Web shortcuts
          sys         System commands (lock, reboot, etc.)
          clipboard   Clipboard history (cliphist / wl-copy)
          custom      User-defined commands
          all         Everything combined   (default)

  --hist-limit N
        Maximum number of history items to load.
        Default: 500

  --clipboard-limit N
        Maximum number of clipboard entries to show.
        Default: 100

Environment Variables:
  FZFLAUNCHER_TERMINAL
        Preferred terminal (kitty, alacritty, footclient, gnome-terminal,
        konsole, xterm).
        Default: kitty

  FZFLAUNCHER_SHELL
        Shell used inside the terminal (fish / bash / zsh).
        Default: fish

  FZFLAUNCHER_MODE
        Default mode when no --mode flag is passed.
        Default: all

  FZFLAUNCHER_HIST_LIMIT
        Overrides the --hist-limit value if set.

  FZFLAUNCHER_CLIPBOARD_LIMIT
        Overrides the --clipboard-limit value if set.

  FZFLAUNCHER_NIRI_JUMP
        true/false — use niri_jump.sh instead of direct focus-window.
        Default: true

  FZFLAUNCHER_USE_APP_CACHE
        true/false — cache parsed .desktop files to speed up app listings.
        Default: true

  FZFLAUNCHER_APP_CACHE
        Path to cached app list.
        Default: ~/.config/fzfLauncher/app_cache

  FZFLAUNCHER_CUST_CMD_FILE
        Custom launcher commands file.
        Default: ~/.config/fzfLauncher/cust_cmds

Examples:
  $0 --mode apps
  $0 --mode windows
  $0 --hist-limit 1000
  $0 --clipboard-limit 50
  $0 --mode clipboard --clipboard-limit 200

EOF
}

# --------------------- ARGUMENT PARSER ---------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-$MODE}"
      shift 2
      ;;
    --hist-limit|--history-limit)
      HIST_LIMIT="${2:-$HIST_LIMIT}"
      shift 2
      ;;
    --clipboard-limit|--clip-limit)
      CLIPBOARD_LIMIT="${2:-$CLIPBOARD_LIMIT}"
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      printf 'fzfLauncher: unknown option: %s\n' "$1" >&2
      printf 'Run with --help to see available options.\n' >&2
      exit 1
      ;;
  esac
done

# --------------------- SETTINGS / ENV OVERRIDES ---------------------

: "${FZFLAUNCHER_TERMINAL:=kitty}"
: "${FZFLAUNCHER_SHELL:=fish}"

: "${FZFLAUNCHER_HIST_LIMIT:=$HIST_LIMIT}"
: "${FZFLAUNCHER_CLIPBOARD_LIMIT:=$CLIPBOARD_LIMIT}"

: "${FZFLAUNCHER_MODE:=$MODE}"

: "${FZFLAUNCHER_KEEP_TERM_OPEN:=1}"

# Base config dirs
: "${XDG_CONFIG_HOME:="$HOME/.config"}"
: "${FZFLAUNCHER_CONFIG_DIR:="$XDG_CONFIG_HOME/fzfLauncher"}"
: "${FZFLAUNCHER_DATA_DIR:="$FZFLAUNCHER_CONFIG_DIR/data"}"
: "${FZFLAUNCHER_CACHE_DIR:="$FZFLAUNCHER_CONFIG_DIR/cache"}"

# Ensure data/cache dirs exist
mkdir -p "$FZFLAUNCHER_DATA_DIR" "$FZFLAUNCHER_CACHE_DIR"

# Files inside data/cache
: "${FZFLAUNCHER_CUST_CMD_FILE:="$FZFLAUNCHER_DATA_DIR/cust_cmds"}"
: "${FZFLAUNCHER_WEB_APPS_FILE:="$FZFLAUNCHER_DATA_DIR/web_apps"}"
: "${FZFLAUNCHER_APP_CACHE:="$FZFLAUNCHER_CACHE_DIR/app_cache"}"

: "${FZFLAUNCHER_WINDOW_GLYPHS:=true}"

: "${FZFLAUNCHER_NIRI_JUMP:=true}"

: "${FZFLAUNCHER_USE_APP_CACHE:=true}"

: "${FZFLAUNCHER_APP_DIRS:="$HOME/.local/share/applications:/usr/share/applications:/var/lib/snapd/desktop/applications"}"

: "${FZFLAUNCHER_LOG_ENABLE:=true}"

: "${FZFLAUNCHER_BUFFER_OPTS:=true}"

# Sync env-driven values back to local vars:
HIST_LIMIT="$FZFLAUNCHER_HIST_LIMIT"
MODE="$FZFLAUNCHER_MODE"

# -------- Load External Config (optional) --------
: "${XDG_CONFIG_HOME:="$HOME/.config"}"
for cfg in \
  "$XDG_CONFIG_HOME/fzfLauncher/config.sh" \
  "$HOME/.config/fzfLauncher/config.sh"
do
  [[ -r "$cfg" ]] && # shellcheck source=/dev/null
  source "$cfg"
done

# --------------------- LOAD UTILS & ENTRIES ---------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Utils
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils/logging.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils/helpers.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils/registry.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils/apps_scan.sh"

# Initialize logging
log_truncate
log "open"

# Entry generators

# shellcheck source=/dev/null

if [[ "$FZFLAUNCHER_WINDOW_GLYPHS" == "true" ]]; then
  source "$SCRIPT_DIR/entries/windows_alt_entries.sh"
else
  source "$SCRIPT_DIR/entries/windows_entries.sh"
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/apps_entries.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/custom_entries.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/history_entries.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/web_entries.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/sys_entries.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/clipboard_entries.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/entries/all_entries.sh"

echo "$MODE"

# --------------------- MODE → GENERATOR DISPATCH ---------------------

case "$MODE" in
  windows)     GEN=windows_entries            TITLE="Windows"   ;;
  apps)        GEN=apps_entries               TITLE="Apps"      ;;
  history)     GEN=history_entries            TITLE="History"   ;;
  web)         GEN=web_entries                TITLE="Web"       ;;
  sys)         GEN=sys_entries                TITLE="System"    ;;
  clipboard)   GEN=clipboard_entries          TITLE="Clipboard" ;;
  custom)      GEN=cust_entries               TITLE="Custom"    ;;
  all)         GEN=all_entries                TITLE="All"       ;;
  *)
    GEN=all_entries
    TITLE="All"
    ;;
esac

# --------------------- GENERATE + FZF ---------------------

sel=""

if [[ "$FZFLAUNCHER_BUFFER_OPTS" == "true" ]]; then
  buf="$("$GEN" | awk -F'\t' 'NF{print $0}')"
  sel="$(
    printf '%s\n' "$buf" \
      | pick_fzf_lines "$TITLE > " \
      || true
  )"
else
  sel="$(
    "$GEN" \
      | awk -F'\t' 'NF{print $0}' \
      | pick_fzf_lines "$TITLE > " \
      || true
  )"
fi

if [[ -z "${sel:-}" ]]; then
  log "no selection (user cancelled)"
  exit 0
fi

label="$(printf "%s" "$sel" | cut -f1)"
cmd="$(printf "%s" "$sel" | cut -f2-)"
cmd="${cmd/"%U"/}"
cmd="${cmd/"%u"/}"

log "sel:     $sel"
log "label:   $label"
log "cmd:     $cmd"

# --------------------- COMMAND EXECUTION ---------------------

if [[ $label == "${PARTS['windows.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['apps.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['history.icon']}"* ]]; then
  open_term 1 "$cmd"
elif [[ $label == "${PARTS['web.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['cust.icon']}"* ]]; then
  open_term 0 "$cmd"
elif [[ $label == "${PARTS['sys.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['clipboard.icon']}"* ]]; then
  run_bg "$cmd"
fi
