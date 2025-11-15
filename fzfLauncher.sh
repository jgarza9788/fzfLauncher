#!/usr/bin/env bash
set -euo pipefail

################################################################################
# fzfLauncher
#
# A fuzzy-launcher script for Wayland/Niri that can show:
#   - current windows
#   - installed apps (.desktop + flatpak)
#   - shell history (fish / zsh / bash)
#   - web shortcuts
#   - clipboard history
#   - simple system commands (lock, reboot, etc.)
#
# This file is the main entry point. Most behavior is controlled by:
#   1) CLI flags (e.g. --mode, --hist-limit, --clipboard-limit)
#   2) Environment variables (FZFLAUNCHER_*)
#
# The general pipeline is:
#   1) Determine MODE + limits from CLI/env.
#   2) Generate "<label>\t<command>" lines for that MODE.
#   3) Pipe into fzf, let the user select a row.
#   4) Run the associated command with app_run/run_bg/open_term.
################################################################################

# --------------------- CLI DEFAULTS ---------------------
# These are the default values *before* environment overrides.
# Environment variables can further customize behavior (see below).

# Which category the launcher should open to:
#   windows|apps|history|web|sys|clipboard|custom|all
MODE="all"

# Maximum number of history entries to read from shell history files.
HIST_LIMIT=500

# Maximum number of clipboard entries to display.
CLIPBOARD_LIMIT=100

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
# Parse simple flag-style arguments:
#   --mode <value>
#   --hist-limit <num>
#   --clipboard-limit <num>
#
# Any unknown flag causes an error (we fail fast so behavior is predictable).

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      # Which logical section of the launcher to open.
      # We intentionally don't validate here to keep the parser simple;
      # an invalid mode will fall back to the default case later.
      MODE="${2:-$MODE}"
      shift 2
      ;;

    --hist-limit|--history-limit)
      # Limit for how many shell history lines we read.
      HIST_LIMIT="${2:-$HIST_LIMIT}"
      shift 2
      ;;

    --clipboard-limit|--clip-limit)
      # Limit for how many clipboard entries we read from cliphist / wl-paste.
      CLIPBOARD_LIMIT="${2:-$CLIPBOARD_LIMIT}"
      shift 2
      ;;

    --help|-h)
      # Print usage information and exit successfully.
      show_help
      exit 0
      ;;

    *)
      # Any other flag is considered invalid. This keeps the UX explicit and
      # helps catch typos in scripts or keybindings.
      printf 'fzfLauncher: unknown option: %s\n' "$1" >&2
      printf 'Run with --help to see available options.\n' >&2
      exit 1
      ;;
  esac
done

# --------------------- SETTINGS / ENV OVERRIDES ---------------------
# From this point on, the script primarily reads configuration from the
# FZFLAUNCHER_* environment variables. The CLI flags above seed the
# initial values, and these env vars allow dotfile-based customization.

# Preferred terminal emulator and login shell.
: "${FZFLAUNCHER_TERMINAL:=kitty}"
: "${FZFLAUNCHER_SHELL:=fish}"

# Limits (CLI values seeded above, but env vars win if present).
: "${FZFLAUNCHER_HIST_LIMIT:=$HIST_LIMIT}"
: "${FZFLAUNCHER_CLIPBOARD_LIMIT:=$CLIPBOARD_LIMIT}"

# Default mode for the picker (all|windows|apps|history|web|sys|clipboard|custom).
: "${FZFLAUNCHER_MODE:=$MODE}"

# Whether history commands should keep the terminal open after execution.
: "${FZFLAUNCHER_KEEP_TERM_OPEN:=1}"

# Path to file with user-defined custom commands (one per line: "label<TAB>cmd").
: "${FZFLAUNCHER_CUST_CMD_FILE:="$HOME/.config/fzfLauncher/cust_cmds"}"

# If true, use a helper script to "jump" to windows instead of a simple focus.
: "${FZFLAUNCHER_NIRI_JUMP:=true}"
# : "${FZFLAUNCHER_NIRI_JUMP:=false}"  # Example override

# Cache a list of apps so it's faster to generate the apps list.
# Note: new apps might not appear immediately when cache is enabled.
: "${FZFLAUNCHER_USE_APP_CACHE:=true}"
: "${FZFLAUNCHER_APP_CACHE:="$HOME/.config/fzfLauncher/app_cache"}"

# Colon-separated list of directories to scan for .desktop files.
: "${FZFLAUNCHER_APP_DIRS:="$HOME/.local/share/applications:/usr/share/applications:/var/lib/snapd/desktop/applications"}"

# should the log be enabled ?
: "${FZFLAUNCHER_LOG_ENABLE:=true}" 

# buffer the options
: "${FZFLAUNCHER_BUFFER_OPTS:=true}" 

# Optional: global fzf defaults (colors, layout, etc.).
# : "${FZF_DEFAULT_OPTS:=}"

# Sync environment-driven values back into the local variables that the rest
# of the script reads. This makes FZFLAUNCHER_* overrides actually effective.
HIST_LIMIT="$FZFLAUNCHER_HIST_LIMIT"
MODE="$FZFLAUNCHER_MODE"

# -------- Load Config --------
# External config hooks so users can tweak behavior without editing this file.
# If present, these are sourced *after* defaults but *before* runtime sections.
: "${XDG_CONFIG_HOME:="$HOME/.config"}"
for cfg in \
  "$XDG_CONFIG_HOME/fzfLauncher/config.sh" \
  "$HOME/.config/fzfLauncher/config.sh"
do
  [[ -r "$cfg" ]] && # shellcheck source=/dev/null
  source "$cfg"
done




# ---------- Registry ----------
# PARTS defines visual "categories" and their icons. In older versions it also
# carried generator/handler names, but now we primarily use it as an icon map.
#
# Each key is of the form "<part>.icon" (e.g., "windows.icon") and is used
# when building the label column shown in fzf.
declare -A PARTS=(
  # part.windows.*
  [windows.icon]=" :"

  # part.apps.*
  [apps.icon]=" :"

  # part.history.*
  [history.icon]="󰋚 :"

  # part.web.*
  [web.icon]="󰖟 :"

  # part.clipboard.*
  [clipboard.icon]=" :"

  # part.cust.*
  [cust.icon]=" :"

  # part.sys.*
  [sys.icon]=" :"
)

# Icons (Nerd Fonts) legend:
#   windows   
#   apps      
#   history   󰋚
#   system    
#   clipboard 
#   web       󰖟

# -------- Logging --------
# Very lightweight logger that timestamps each entry and keeps only the last
# MAX_LINES lines to prevent unbounded growth.

LOGFILE="$HOME/.config/fzfLauncher/log.txt"
MAX_LINES=1000

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"
# Ensure log file exists
touch "$LOGFILE"

log() {

  if [[ "$FZFLAUNCHER_LOG_ENABLE" ==  "false" ]]; then

    return 0;
  fi 

  local msg="$*"
  local timestamp
  # Example format: 2025-11-08 19:21:45
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s | %s\n' "$timestamp" "$msg" >>"$LOGFILE"
}

log_truncate() {
  # Truncate the log file if it grows beyond MAX_LINES lines.
  local lines
  lines=$(wc -l <"$LOGFILE")

  if (( lines > MAX_LINES )); then
    # Keep the last MAX_LINES lines in-place.
    tail -n "$MAX_LINES" "$LOGFILE" >"$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  fi
}

log_truncate
log "open"

# --------------------- Helper Functions ---------------------

# have: test if a command exists in PATH.
have() {
  command -v "$1" >/dev/null 2>&1
}

# copy_clip: write text into the system clipboard using Wayland or X11 tools.
copy_clip() {
  if have wl-copy; then
    printf "%s" "$1" | wl-copy
  elif have xclip; then
    printf "%s" "$1" | xclip -selection clipboard
  fi
}

# app_run: run a command detached from this shell, with a short delay to give
# the new window time to appear before the launcher exits.
app_run() {
  setsid nohup bash -lc "$1" >/dev/null 2>&1 & disown
  sleep 0.5
}

# run_bg: non-terminal background launcher (used mostly for clipboard/sys).
# Same pattern as app_run but kept separate for clarity and future tuning.
run_bg() {
  nohup bash -lc "$1" >/dev/null 2>&1 &
  sleep 0.5
}

# open_term: open a terminal and run a command inside a shell.
#
# Arguments:
#   $1 - KEEP_TERM_OPEN (1 = keep open, 0 = close after command)
#   $2 - cmd string to execute in the shell
#
# It uses FZFLAUNCHER_TERMINAL and FZFLAUNCHER_SHELL to decide how to launch.
open_term() {
  local KEEP_TERM_OPEN=$1
  local cmd="$2"

  local shell="$FZFLAUNCHER_SHELL"
  local terminal="$FZFLAUNCHER_TERMINAL"
  local term=()

  # First: respect the explicit terminal choice if supported.
  case "$terminal" in
    kitty)          term=(kitty -e) ;;
    alacritty)      term=(alacritty -e) ;;
    footclient)     term=(footclient -e) ;;
    gnome-terminal) term=(gnome-terminal -- bash -lc) ;;
    konsole)        term=(konsole -e) ;;
    xterm)          term=(xterm -e) ;;
  esac

  # Fallback: auto-detect an available terminal.
  if (( ${#term[@]} == 0 )); then
    if   have kitty;          then term=(kitty -e)
    elif have alacritty;      then term=(alacritty -e)
    elif have footclient;     then term=(footclient -e)
    elif have gnome-terminal; then term=(gnome-terminal -- bash -lc)
    elif have konsole;        then term=(konsole -e)
    else                           term=(xterm -e)
    fi
  fi

  # Build the actual launch command line, depending on whether we want
  # the terminal to stay open after the command completes.
  if [[ "$KEEP_TERM_OPEN" -eq 1 ]]; then
    case "$shell" in
      fish) app_run "${term[*]} fish -ic \"$cmd; and fish\"" ;;
      bash) app_run "${term[*]} bash -ic \"$cmd; exec bash\"" ;;
      zsh)  app_run "${term[*]} zsh  -ic \"$cmd; exec zsh\"" ;;
      *)    app_run "${term[*]} bash -ic \"$cmd; exec bash\"" ;;
    esac
  else
    case "$shell" in
      fish) app_run "${term[*]} fish -lc \"$cmd\"" ;;
      bash) app_run "${term[*]} bash -lc \"$cmd\"" ;;
      zsh)  app_run "${term[*]} zsh  -lc \"$cmd\"" ;;
      *)    app_run "${term[*]} bash -lc \"$cmd\"" ;;
    esac
  fi
}

# --------------------- ENTRY GENERATORS ---------------------
# Each generator prints lines in the format:
#
#   <label>\t<command>
#
# The label is what's shown in fzf; the command is what we execute afterwards.

# 1) Niri windows: use niri IPC to list windows with IDs and a command that
# can focus (or jump to) the selected window.
windows_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['windows.icon']}"

  # By default we call niri directly; optionally we can delegate to a script
  # for more complex jumping behavior.
  local switch_cmd="niri msg action focus-window --id"
  if $FZFLAUNCHER_NIRI_JUMP; then
    switch_cmd="$HOME/.config/fzfLauncher/niri_jump.sh"
  fi

  # If niri is not available, nothing to do.
  if ! have niri; then
    return 0
  fi

  if have jq; then
    # JSON IPC path (preferred): we parse the window list and build a neat label.
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

# 2) Apps: collect .desktop files and flatpaks and generate commands to launch
# them. Optionally uses a cache file to speed up subsequent runs.
apps_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['apps.icon']}"

  if [[ -f "$FZFLAUNCHER_APP_CACHE" && "$FZFLAUNCHER_USE_APP_CACHE" == "true" ]]; then
    # Cached format is already "<name>\t<exec>" (minus icon); we prepend icon.
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
    done <"$FZFLAUNCHER_APP_CACHE"
  else
    log "no app_cache"

    # Find .desktop files in the configured app dirs.
    for d in ${FZFLAUNCHER_APP_DIRS//:/ }; do
      [[ -d "$d" ]] && find "$d" -maxdepth 1 -type f -name "*.desktop"
    done \
      | while IFS= read -r desk; do
          local id name exec
          id="$(basename "$desk" .desktop)"
          name="$(grep -m1 -E '^Name=' "$desk" | sed 's/^Name=//' || true)"
          [[ -z "$name" ]] && name="$id"

          exec="$(grep -m1 -E '^Exec=' "$desk" | sed 's/^Exec=//' || true)"
          # Strip desktop file placeholders like %f, %u, etc.
          exec="$(printf '%s' "$exec" | sed -E 's/ *%[fFuUdDnNickvm]//g')"

          printf "%s %s\t%s\n" "$icon" "$name" "$exec"
        done \
      | awk -F'\t' '!seen[$2]++'

    # Also add Flatpak apps, if flatpak is installed.
    if have flatpak; then
      flatpak list --app --columns=name,application \
        | tail -n +1 \
        | while IFS=$'\t' read -r name appid; do
            printf "%s %s\tflatpak run %s\n" "$icon" "$name" "$appid"
          done \
        | awk -F'\t' '!seen[$2]++'
    fi
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "apps_entries exec-time ${diff_ns}ns"
}

# If app caching is enabled, update the cache asynchronously after generating.
if [[ "$FZFLAUNCHER_USE_APP_CACHE" == "true" ]]; then
  SET_APP_CACHE="$HOME/.config/fzfLauncher/set_app_cache.sh"
  app_run "$SET_APP_CACHE \"$FZFLAUNCHER_APP_DIRS\" \"$FZFLAUNCHER_APP_CACHE\""
fi

# 2.1 Customs: user-defined commands loaded from FZFLAUNCHER_CUST_CMD_FILE.
# Each line in that file should be "<label>\t<command>" (or similar).
cust_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['cust.icon']}"

  if [[ -f "$FZFLAUNCHER_CUST_CMD_FILE" ]]; then
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
    done <"$FZFLAUNCHER_CUST_CMD_FILE"
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "cust_entries exec-time ${diff_ns}ns"
}

# 3) History: fish / bash / zsh
# Uses HIST_LIMIT (synced from FZFLAUNCHER_HIST_LIMIT) to limit items.

hist_fish() {
  local icon="${PARTS['history.icon']}"
  local f="$HOME/.local/share/fish/fish_history"
  [[ -r "$f" ]] || return 0

  tac "$f" \
    | awk '$1=="-" && $2=="cmd:" { sub(/^- cmd: /,""); print }' \
    | awk 'NF' \
    | sed 's/^[ \t]\+//;s/[ \t]\+$//' \
    | awk 'seen[$0]++==0 {print}' \
    | head -n "$HIST_LIMIT" \
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
    | head -n "$HIST_LIMIT" \
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
    | head -n "$HIST_LIMIT" \
    | while IFS= read -r c; do
        printf "%s [zsh] %s\t%s\n" "$icon" "$c" "$c"
      done
}

history_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  {
    hist_fish
    hist_zsh
    hist_bash
  }

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "hist_entries exec-time ${diff_ns}ns"
}

# 4) Web: static list of common web apps.
# You can trim or extend this list to fit your own usage.
web_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['web.icon']}"
  local web_apps="$HOME/.config/fzfLauncher/web_apps"

  if [[ -f "$web_apps" ]]; then
    while IFS= read -r line; do
      printf '%s %s\n' "$icon" "$line"
    done <"$web_apps"
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "web_entries exec-time ${diff_ns}ns"
}

# 5) System: basic lock/reboot/shutdown/logout entries.

# locker_cmd: choose the most appropriate screen locker installed.
locker_cmd() {
  if   have hyprlock; then echo "hyprlock"
  elif have swaylock; then echo "swaylock -f"
  elif have i3lock;   then echo "i3lock"
  elif have dm-tool;  then echo "dm-tool lock"
  else                     echo "loginctl lock-session"
  fi
}

sys_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['sys.icon']}"
  local lock
  lock="$(locker_cmd)"

  cat <<EOF
$icon  Lock	$lock
$icon 󰐥 Shutdown	systemctl poweroff
$icon 󰐥 PowerOff	systemctl poweroff
$icon 󰜉 Reboot	systemctl reboot
$icon 󰜉 Restart	systemctl reboot
$icon 󰍃 Logout	loginctl terminate-user "$USER"
EOF

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "sys_entries exec-time ${diff_ns}ns"
}

# Clipboard entries: show clipboard history and commands to re-copy selections
# back into wl-copy/xclip. Behavior depends on which tools are installed.
clipboard_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['clipboard.icon']}"

  # ------------------------------
  # Collect clipboard history
  # ------------------------------

  if have cliphist; then
    # cliphist: we get tokens, then decode into actual content.
    cliphist list | head -n "$FZFLAUNCHER_CLIPBOARD_LIMIT" \
      | while IFS= read -r token; do
          local content display esc_payload

          content="$(printf '%s' "$token" | cliphist decode)"

          # Flatten to single-line preview text.
          display="$(
            printf '%s' "$content" \
              | tr '\n\r\t' ' ' \
              | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
              | head -c 200
          )"

          # Shell-escape the payload for safe inlining into the command.
          esc_payload="$(printf '%q' "$content")"

          # label<TAB>command
          printf "%s %s\tprintf %%s %s | wl-copy\n" "$icon" "$display" "$esc_payload"
        done

  elif command -v wl-paste-history >/dev/null 2>&1; then
    # wl-paste-history: if present, list and trim.
    wl-paste-history list \
      | head -n "$FZFLAUNCHER_CLIPBOARD_LIMIT" \
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
        done

  elif have xclip; then
    # xclip has no history; we only show the current clipboard contents.
    local content display esc_payload

    content="$(xclip -selection clipboard -o 2>/dev/null || true)"
    content="$(printf "%s" "$content" | head -n "$FZFLAUNCHER_CLIPBOARD_LIMIT" | tac)"

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
    }
  fi

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "clipboard_entries exec-time ${diff_ns}ns"
}

# --------------------- MIXERS ---------------------
# Helpers that combine or decorate multiple sources.

# decorate: prepend a category tag for readability in "all" view.
decorate() {
  local tag="$1"
  awk -F'\t' -v T="$tag" 'NF{printf "%s: %s\t%s\n",T,$1,$2}'
}

# all_entries: aggregate all sections into one big list.
all_entries() {
  {
    windows_entries
    cust_entries
    apps_entries
    history_entries
    web_entries
    clipboard_entries
    sys_entries
  }
}

notclipboard_entries(){
  {
    windows_entries
    cust_entries
    apps_entries
    history_entries
    web_entries
    sys_entries
  }
}

# lookup_cmd_from: given a generator name and a label, find the matching cmd.
# (Currently unused, but kept for future extension if we need "replay by label".)
lookup_cmd_from() {
  local generator="$1" label="$2"
  "$generator" | awk -F'\t' -v L="$label" '($1==L){print $2; exit}'
}

# --------------------- Selection Engine ---------------------
# pick_fzf_lines: read "<label>\t<cmd>" lines on stdin and return the selected
# full line, using fzf with a simple preview.

pick_fzf_lines() {
  local prompt="$1"

  fzf --with-nth=1 --delimiter=$'\t' --ansi \
      --highlight-line \
      --prompt="$prompt" \
      --preview='echo -e "Command:\n"$(echo {} | cut -f2-)' \
      --preview-window='down,3,wrap'
}

# --------------------- CLI DISPATCH ---------------------
# Decide which generator to use based on MODE.

echo $MODE

case "$MODE" in
  windows)     GEN=windows_entries            TITLE="Windows"   ;;
  apps)        GEN=apps_entries               TITLE="Apps"      ;;
  history)     GEN=history_entries            TITLE="History"   ;;
  web)         GEN=web_entries                TITLE="Web"       ;;
  sys)         GEN=sys_entries                TITLE="System"    ;;
  clipboard)   GEN=clipboard_entries          TITLE="Clipboard" ;;
  custom)      GEN=cust_entries               TITLE="Custom"    ;;
  notcb)       GEN=notclipboard_entries       TITLE="All*"       ;;
  all)         GEN=all_entries                TITLE="All"       ;;
  *)
    # Safety net: unknown mode falls back to "all".
    GEN=all_entries
    TITLE="All"
    ;;
esac

# Generate entries, strip empty lines, and hand them to fzf.

sel="";

if [[ "$FZFLAUNCHER_BUFFER_OPTS" == "true" ]]; then

  # this buffer will collect the data so all items appear at the same time
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


# If the user pressed ESC or nothing was selected, exit quietly.
if [[ -z "${sel:-}" ]]; then
  log "no selection (user cancelled)"
  exit 0
fi

# Split the selected line into label and command.
label="$(printf "%s" "$sel" | cut -f1)"
cmd="$(printf "%s" "$sel" | cut -f2-)"
cmd="${cmd/"%U"/}"
cmd="${cmd/"%u"/}"

log "sel:     $sel"
log "label:   $label"
log "cmd:     $cmd"

# --------------------- Command Execution ---------------------
# Decide how to run the selected command based on which icon prefix the label
# starts with. This uses the PARTS icon strings as markers.

if [[ $label == "${PARTS['windows.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['apps.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['history.icon']}"* ]]; then
  # For history, we usually want a terminal that stays open.
  open_term 1 "$cmd"
elif [[ $label == "${PARTS['web.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['cust.icon']}"* ]]; then
  # Custom commands: by default, run in a terminal that closes afterwards.
  open_term 0 "$cmd"
elif [[ $label == "${PARTS['sys.icon']}"* ]]; then
  app_run "$cmd"
elif [[ $label == "${PARTS['clipboard.icon']}"* ]]; then
  # Clipboard actions generally just re-copy content, no terminal needed.
  run_bg "$cmd"
fi
