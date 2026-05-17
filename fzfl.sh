#!/usr/bin/env bash
set -euo pipefail

APP_NAME="fzfl"

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fzfl"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fzfl"
CFG_FILE="$CFG_DIR/config.sh"
WEBAPPS_FILE="$CFG_DIR/webapps.tsv"

mkdir -p "$CFG_DIR" "$CACHE_DIR"

# ---------------------------
# Help
# ---------------------------
show_help() {
  cat <<'EOF'
fzfl - fzf launcher (apps, web, history, clipboard, niri windows)

Usage:
  fzfl
  fzfl --help
  fzfl --rebuild-cache
  fzfl --print-config

Hotkeys (inside fzf):
  Enter      default action (launch / run / focus / copy)
  Ctrl-y     copy selected item's "value" to clipboard
  Ctrl-e     edit-before-run (HIST only; requires FZFL_EDIT_BEFORE_RUN=1)
  Alt-Enter  alternate action (WEB: open as tab, APP: print exec)

Notes:
  - Apps + History are cached in ~/.cache/fzfl
  - Clipboard uses cliphist + wl-copy (Wayland)
  - Windows use: niri msg --json windows
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
  exit 0
fi

# ---------------------------
# Load config with defaults
# ---------------------------
# Defaults (in case config missing)
FZFL_TERMINAL="${FZFL_TERMINAL:-kitty}"
FZFL_BROWSER="${FZFL_BROWSER:-chromium}"
FZFL_WEB_MODE="${FZFL_WEB_MODE:-window}"
FZFL_EDIT_BEFORE_RUN="${FZFL_EDIT_BEFORE_RUN:-0}"
FZFL_CACHE_TTL_APPS="${FZFL_CACHE_TTL_APPS:-604800}"
FZFL_CACHE_TTL_HISTORY="${FZFL_CACHE_TTL_HISTORY:-86400}"

FZFL_ENABLE_APPS="${FZFL_ENABLE_APPS:-1}"
FZFL_ENABLE_WEB="${FZFL_ENABLE_WEB:-1}"
FZFL_ENABLE_HIST="${FZFL_ENABLE_HIST:-1}"
FZFL_ENABLE_CLIP="${FZFL_ENABLE_CLIP:-1}"
FZFL_ENABLE_WIN="${FZFL_ENABLE_WIN:-1}"

FZFL_LABEL_APPS="${FZFL_LABEL_APPS:-A}"
FZFL_LABEL_WEB="${FZFL_LABEL_WEB:-W}"
FZFL_LABEL_WIN="${FZFL_LABEL_WIN:-W}"
FZFL_LABEL_CLIP="${FZFL_LABEL_CLIP:-C}"
FZFL_LABEL_HIST="${FZFL_LABEL_HIST:-H}"

FZFL_EXTRA_APP_DIRS="${FZFL_EXTRA_APP_DIRS:-}"

FZFL_WIN_JUMP="${FZFL_WIN_JUMP:-1}"

FZFL_CLIP_MAX="${FZFL_CLIP_MAX:-250}"


# shellcheck disable=SC1090
[[ -f "$CFG_FILE" ]] && source "$CFG_FILE"

if [[ "${1:-}" == "--print-config" ]]; then
  echo "CFG_FILE=$CFG_FILE"
  echo "CACHE_DIR=$CACHE_DIR"
  echo "WEBAPPS_FILE=$WEBAPPS_FILE"
  echo "FZFL_TERMINAL=$FZFL_TERMINAL"
  echo "FZFL_BROWSER=$FZFL_BROWSER"
  echo "FZFL_WEB_MODE=$FZFL_WEB_MODE"
  echo "FZFL_EDIT_BEFORE_RUN=$FZFL_EDIT_BEFORE_RUN"
  echo "FZFL_CACHE_TTL_APPS=$FZFL_CACHE_TTL_APPS"
  echo "FZFL_CACHE_TTL_HISTORY=$FZFL_CACHE_TTL_HISTORY"
  exit 0
fi

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need_cmd fzf
need_cmd jq

# wl-copy and cliphist only if enabled
[[ "$FZFL_ENABLE_CLIP" == "1" ]] && { need_cmd wl-copy; need_cmd cliphist; }
[[ "$FZFL_ENABLE_WIN" == "1" ]] && need_cmd niri

# ---------------------------
# Helpers
# ---------------------------
now_epoch() { date +%s; }

cache_is_fresh() {
  local file="$1" ttl="$2"
  [[ -f "$file" ]] || return 1
  local mtime
  mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
  local age=$(( $(now_epoch) - mtime ))
  (( age <= ttl ))
}

# Payload delimiter design:
# Visible column 1: pretty label
# Column 2: "__fzfl__"
# Column 3+: key=value payload fields
DELIM=$'\t'
SENTINEL="__fzfl__"

emit_line() {
  # emit_line "<pretty>" "type=APP" "k=v" ...
  local pretty="$1"; shift
  printf '%s%s%s' "$pretty" "$DELIM" "$SENTINEL"
  for kv in "$@"; do
    printf '%s%s' "$DELIM" "$kv"
  done
  printf '\n'
}

payload_get() {
  # payload_get "$line" "key"
  local line="$1" key="$2"
  # Split on tabs, find key=
  local part
  IFS=$'\t' read -r -a cols <<<"$line"
  for part in "${cols[@]}"; do
    if [[ "$part" == "$key="* ]]; then
      printf '%s' "${part#"$key="}"
      return 0
    fi
  done
  return 1
}

copy_to_clipboard() {
  local text="$1"
  printf '%s' "$text" | wl-copy
}

# Terminal command builder
term_run() {
  local cmd="$1"

  # Optional edit-before-run
  if [[ "${FZFL_EDIT_BEFORE_RUN:-0}" == "1" ]]; then
    local tmp
    tmp="$(mktemp)"
    printf '%s\n' "$cmd" >"$tmp"
    "${EDITOR:-nano}" "$tmp"
    cmd="$(cat "$tmp" 2>/dev/null || true)"
    rm -f "$tmp"
    [[ -n "${cmd//[[:space:]]/}" ]] || return 0
  fi

  

  local shell="${FZFL_SHELL:-bash}"
  local -a argv=()
  case "${FZFL_TERMINAL:-kitty}" in
    kitty)
      argv=(kitty --hold "$shell" -ic "$cmd")
      ;;
    gnome-terminal)
      argv=(gnome-terminal -- "$shell" -ic "$cmd")
      ;;
    alacritty)
      argv=(alacritty -e "$shell" -ic "$cmd")
      ;;
    *)
      echo "Unknown FZFL_TERMINAL=${FZFL_TERMINAL:-} (use kitty|gnome-terminal|alacritty)" >&2
      return 1
      ;;
  esac

  echo "${argv[@]}"

  # Fully detach: new session + no stdin + no output
  setsid -f "${argv[@]}" </dev/null >/dev/null 2>&1 &

  # In interactive shells, this prevents SIGHUP when the parent exits
  disown 2>/dev/null || true


}


# term_run() {
#   local cmd="$1"

#   # Optional edit-before-run
#   if [[ "${FZFL_EDIT_BEFORE_RUN:-0}" == "1" ]]; then
#     local tmp
#     tmp="$(mktemp)"
#     printf '%s\n' "$cmd" >"$tmp"
#     "${EDITOR:-nano}" "$tmp"
#     cmd="$(cat "$tmp" || true)"
#     rm -f "$tmp"
#     [[ -n "${cmd// }" ]] || exit 0
#   fi

#   local -a argv=()
#   case "${FZFL_TERMINAL:-kitty}" in
#     kitty)
#       argv=(kitty --hold sh -lc "$cmd")
#       ;;
#     gnome-terminal)
#       argv=(gnome-terminal -- bash -lc "$cmd")
#       ;;
#     alacritty)
#       argv=(alacritty -e bash -lc "$cmd")
#       ;;
#     *)
#       echo "Unknown FZFL_TERMINAL=${FZFL_TERMINAL:-} (use kitty|gnome-terminal|alacritty)" >&2
#       exit 1
#       ;;
#   esac

#   nohup "${argv[@]}" >/dev/null 2>&1 &
# }



# term_run() {
#   local cmd="$1"

#   # If edit-before-run is enabled, allow user to modify in $EDITOR
#   if [[ "$FZFL_EDIT_BEFORE_RUN" == "1" ]]; then
#     local tmp
#     tmp="$(mktemp)"
#     printf '%s\n' "$cmd" >"$tmp"
#     "${EDITOR:-nano}" "$tmp"
#     cmd="$(cat "$tmp" || true)"
#     rm -f "$tmp"
#     [[ -n "$cmd" ]] || exit 0
#   fi

#   local -a tpl=()
#   case "$FZFL_TERMINAL" in
#     kitty)         tpl=("${FZFL_TERM_KITTY[@]:-kitty --hold sh -lc "{cmd}"}") ;;
#     gnome-terminal) tpl=("${FZFL_TERM_GNOME[@]:-gnome-terminal -- bash -lc "{cmd}"}") ;;
#     alacritty)     tpl=("${FZFL_TERM_ALACRITTY[@]:-alacritty -e bash -lc "{cmd}"}") ;;
#     *)
#       echo "Unknown FZFL_TERMINAL=$FZFL_TERMINAL (use kitty|gnome-terminal|alacritty)" >&2
#       exit 1
#       ;;
#   esac

#   # Replace {cmd} placeholder in each arg (safely)
#   local -a argv=()
#   local a
#   for a in "${tpl[@]}"; do
#     argv+=("${a//\{cmd\}/$cmd}")
#   done

#   # Launch detached
#   nohup "${argv[@]}" >/dev/null 2>&1 &
# }

# ---------------------------
# Source: WEB
# ---------------------------
source_web() {
  [[ -f "$WEBAPPS_FILE" ]] || return 0
  # format: Name<TAB>URL
  while IFS=$'\t' read -r name url; do
    [[ -z "${name// }" || -z "${url// }" ]] && continue
    emit_line "$FZFL_LABEL_WEB $name" "type=WEB" "name=$name" "url=$url"
  done <"$WEBAPPS_FILE"
}

web_open() {
  local url="$1"
  case "$FZFL_WEB_MODE" in
    app) nohup "$FZFL_BROWSER" --app="$url" >/dev/null 2>&1 & ;;
    *)   nohup "$FZFL_BROWSER" --new-window "$url" >/dev/null 2>&1 & ;;
  esac
}

web_open_tab() {
  local url="$1"
  nohup "$FZFL_BROWSER" "$url" >/dev/null 2>&1 &
}

# ---------------------------
# Source: APPS (cached)
# ---------------------------
APPS_CACHE="$CACHE_DIR/apps.tsv"

desktop_exec_from_file() {
  # best-effort parse Exec= line (strip field codes)
  local f="$1"
  local exec_line
  exec_line="$(grep -m1 '^Exec=' "$f" 2>/dev/null || true)"
  exec_line="${exec_line#Exec=}"
  # Strip common desktop field codes: %u %U %f %F %i %c %k
  exec_line="${exec_line//%u/}"
  exec_line="${exec_line//%U/}"
  exec_line="${exec_line//%f/}"
  exec_line="${exec_line//%F/}"
  exec_line="${exec_line//%i/}"
  exec_line="${exec_line//%c/}"
  exec_line="${exec_line//%k/}"
  # collapse spaces
  echo "$exec_line" | awk '{$1=$1;print}'
}

desktop_name_from_file() {
  local f="$1"
  local name_line
  name_line="$(grep -m1 '^Name=' "$f" 2>/dev/null || true)"
  echo "${name_line#Name=}"
}

desktop_terminal_from_file() {
  local f="$1"
  local t
  t="$(grep -m1 '^Terminal=' "$f" 2>/dev/null || true)"
  t="${t#Terminal=}"
  [[ "$t" == "true" ]] && echo "1" || echo "0"
}

is_hidden_desktop() {
  local f="$1"
  grep -Eq '^(NoDisplay=true|Hidden=true)$' "$f" 2>/dev/null
}

apps_rebuild_cache() {
  local tmp
  tmp="$(mktemp)"
  local -a dirs=(
    "/usr/share/applications"
    "/usr/local/share/applications"
    "$HOME/.local/share/applications"
    "/var/lib/flatpak/exports/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
  )

  if [[ -n "$FZFL_EXTRA_APP_DIRS" ]]; then
    IFS=':' read -r -a extra <<<"$FZFL_EXTRA_APP_DIRS"
    dirs+=("${extra[@]}")
  fi

  local d f name exec term
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || continue
    while IFS= read -r -d '' f; do
      [[ -f "$f" ]] || continue
      is_hidden_desktop "$f" && continue

      name="$(desktop_name_from_file "$f")"
      [[ -n "${name// }" ]] || continue

      exec="$(desktop_exec_from_file "$f")"
      [[ -n "${exec// }" ]] || continue

      term="$(desktop_terminal_from_file "$f")"

      # use basename as id
      emit_line "$FZFL_LABEL_APPS $name" "type=APP" "name=$name" "exec=$exec" "term=$term" "id=$(basename "$f")" >>"$tmp"

    done < <(find -L "$d" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
  done

  mv "$tmp" "$APPS_CACHE"
}

source_apps() {
  if ! cache_is_fresh "$APPS_CACHE" "$FZFL_CACHE_TTL_APPS"; then
    apps_rebuild_cache
  fi
  [[ -f "$APPS_CACHE" ]] && cat "$APPS_CACHE"
}

# ---------------------------
# Source: HISTORY (cached)
# ---------------------------
HIST_CACHE="$CACHE_DIR/history.tsv"

history_rebuild_cache() {
  local tmp
  tmp="$(mktemp)"

  # Bash history
  local bash_file="${HISTFILE:-$HOME/.bash_history}"
  if [[ -f "$bash_file" ]]; then
    # take last 5000 lines to keep cache reasonable
    tail -n 5000 "$bash_file" 2>/dev/null \
      | sed '/^[[:space:]]*$/d' \
      | while IFS= read -r cmd; do
          emit_line "$FZFL_LABEL_HIST $cmd" "type=HIST" "shell=bash" "cmd=$cmd"
        done >>"$tmp"
  fi

  # Zsh history (often: ": 1700000000:0;command")
  local zsh_file="$HOME/.zsh_history"
  if [[ -f "$zsh_file" ]]; then
    tail -n 8000 "$zsh_file" 2>/dev/null \
      | sed -E 's/^: [0-9]+:[0-9]+;//' \
      | sed '/^[[:space:]]*$/d' \
      | while IFS= read -r cmd; do
          emit_line "$FZFL_LABEL_HIST $cmd" "type=HIST" "shell=zsh" "cmd=$cmd"
        done >>"$tmp"
  fi

  # Fish history (yaml-ish). Extract "cmd:" lines.
  local fish_file="$HOME/.local/share/fish/fish_history"
  if [[ -f "$fish_file" ]]; then
    # take last chunk; fish file can be large
    tail -n 12000 "$fish_file" 2>/dev/null \
      | awk '
          $1=="-"{inblock=1}
          $1=="cmd:"{
            sub(/^cmd:[ ]*/, "", $0);
            print $0
          }' \
      | sed '/^[[:space:]]*$/d' \
      | while IFS= read -r cmd; do
          emit_line "$FZFL_LABEL_HIST $cmd" "type=HIST" "shell=fish" "cmd=$cmd"
        done >>"$tmp"
  fi

  # Deduplicate by cmd text, keep last occurrence (newer-ish)
  # We’ll parse payload cmd=... from column list by splitting on tabs.
  awk -F'\t' '
    {
      cmd="";
      for(i=1;i<=NF;i++){
        if($i ~ /^cmd=/){ cmd=substr($i,5); break }
      }
      if(cmd!=""){ last[cmd]=$0; order[++n]=cmd }
    }
    END{
      # print in the order we saw them, but only the final stored line
      seen_count=0
      for(i=1;i<=n;i++){
        c=order[i]
        if(printed[c]++) continue
      }
      # We printed nothing yet: do it from oldest->newest-ish by iterating order,
      # but only emit the final line once, at the last time it appears:
      delete printed
      for(i=1;i<=n;i++){
        c=order[i]
        # check if this is the last time c appears
        if(i<n && order[i+1]==c) continue
      }
      # Easier: just emit last[] in insertion order using a second pass:
    }' "$tmp" >/dev/null 2>&1 || true

  # Simple, reliable dedupe: reverse, keep first, reverse back
  tac "$tmp" \
    | awk -F'\t' '
        {
          cmd="";
          for(i=1;i<=NF;i++){
            if($i ~ /^cmd=/){ cmd=substr($i,5); break }
          }
          if(cmd=="" || seen[cmd]++) next
          print
        }' \
    | tac >"$tmp.dedup"

  mv "$tmp.dedup" "$HIST_CACHE"
  rm -f "$tmp" || true
}

source_history() {
  if ! cache_is_fresh "$HIST_CACHE" "$FZFL_CACHE_TTL_HISTORY"; then
    history_rebuild_cache
  fi
  [[ -f "$HIST_CACHE" ]] && cat "$HIST_CACHE"
}

# ---------------------------
# Source: CLIP (live)
# ---------------------------
source_clip() {
  # cliphist list output is typically:
  # "12345 <content preview>"
  cliphist list 2>/dev/null | head -n $FZFL_CLIP_MAX | while IFS= read -r line; do
    [[ -n "${line// }" ]] || continue
    # store full line; decode later by id
    local id="${line%% *}"
    emit_line "$FZFL_LABEL_CLIP ${line#* }" "type=CLIP" "id=$id"
  done
}

clip_restore() {
  local id="$1"
  # Decode and re-copy to clipboard
  cliphist decode <<<"$id" | wl-copy
}

# ---------------------------
# Source: WIN (niri live)
# ---------------------------

source_windows() {
  # Expect JSON output. We’ll do best-effort extraction for id + title/app_id/workspace.
  # Niri JSON shape may evolve; this is intentionally defensive.

  ###########################################
  # niri msg --json windows 2>/dev/null \
  #   | jq -r '
  #       def str(x): (x|tostring);
  #       . as $root
  #       | (.. | objects | select(has("id") and (has("title") or has("app_id") or has("appId"))) ) as $w
  #       | [
  #           ($w.id),
  #           ($w.title // $w.name // ""),
  #           ($w.app_id // $w.appId // ""),
  #           ($w.workspace // $w.workspace_id // $w.workspaceId // "")
  #         ]
  #       | @tsv
  #     ' 2>/dev/null \
  #   | while IFS=$'\t' read -r id title app ws; do
  #       [[ -n "${id// }" ]] || continue

  #       # local base="$title"
  #       # [[ -n "${base// }" ]] || base="$app"

  #       # if [[ -n "${ws// }" ]]; then
  #       #   label="[$ws] $base"
  #       # else
  #       #   label="$base"
  #       # fi

  #       label="[$ws] $app | $title"

  #       emit_line "$FZFL_LABEL_WIN $label" \
  #         "type=WIN" "id=$id" "title=$title" "app=$app" "ws=$ws"
  #     done
  ###########################################

  local count=0

  local ACTIVE=""
  local INACTIVE=""
  local URGENT="󰎃"
  local FLOAT_ACTIVE="󰄶"
  local FLOAT_INACTIVE="󰄷"

  get() {
    niri msg -j "$1" 2>/dev/null || niri msg --json "$1" 2>/dev/null || true
  }

  local windows workspaces
  windows="$(get windows)"
  workspaces="$(get workspaces)"

  # Iterate workspaces (process substitution so $count updates persist)
  while IFS= read -r ws; do
    local wsid wsidx
    wsid="$(jq -r '.id'  <<<"$ws")"
    wsidx="$(jq -r '.idx' <<<"$ws")"

    # -------- Floating windows in this workspace --------
    local fwswindows fwcount index
    fwswindows="$(printf '%s' "$windows" | jq --arg ws_id "$wsid" '
      [
        .[]?
        | select((.workspace_id | tostring) == $ws_id)
        | select(.is_floating == true)
        | . + {order: (.layout.pos_in_scrolling_layout[0]
                     // .layout.tile_pos_in_workspace_view[0]
                     // 999999)}
      ]
      | sort_by(.order)
    ')"

    fwcount="$(jq 'length' <<<"$fwswindows")"
    count=$((count + fwcount))

    index="$fwcount"
    while IFS= read -r win; do
      local title app_id winid text char i
      title="$(jq -r '.title  // "unknown"' <<<"$win")"
      app_id="$(jq -r '.app_id // "unknown"' <<<"$win")"
      winid="$(jq -r '.id     // "unknown"' <<<"$win")"

      text="$wsidx | "
      for i in $(seq 1 "$fwcount"); do
        if [[ "$i" == "$index" ]]; then
          char="$FLOAT_ACTIVE"
        else
          char="$FLOAT_INACTIVE"
        fi
        text+="$char "
      done

      text+="                    "
      text="${text:0:20}"

      # printf '%s %-20s %s\t%s\n' \
        # "$FZFL_LABEL_WIN" "$text" "$app_id $title" "type=WIN" "id=$id"

      emit_line "$FZFL_LABEL_WIN $text $app_id | $title" "type=WIN" "id=$winid" 

  #       emit_line "$FZFL_LABEL_WIN $label" \
  #         "type=WIN" "id=$id" "title=$title" "app=$app" "ws=$ws"


      ((index--))
    done < <(jq -c 'sort_by(-.order)[]' <<<"$fwswindows")

    # -------- Tiled windows in this workspace --------
    local wswindows wcount
    wswindows="$(printf '%s' "$windows" | jq --arg ws_id "$wsid" '
      [
        .[]?
        | select((.workspace_id | tostring) == $ws_id)
        | select(.is_floating == false)
        | . + {order: (.layout.pos_in_scrolling_layout[0] // 999999)}
      ]
      | sort_by(.order)
    ')"

    wcount="$(jq 'length' <<<"$wswindows")"
    count=$((count + wcount))

    while IFS= read -r win; do
      local order title app_id winid text char i
      order="$(jq -r '.order // -1' <<<"$win")"
      title="$(jq -r '.title // "unknown"' <<<"$win")"
      app_id="$(jq -r '.app_id // "unknown"' <<<"$win")"
      winid="$(jq -r '.id // "unknown"' <<<"$win")"

      text="$wsidx | "
      for i in $(seq 1 "$wcount"); do
        if [[ "$i" -eq "$order" ]]; then
          char="$ACTIVE"
        else
          char="$INACTIVE"
        fi
        text+="$char "
      done

      text+="                    "
      text="${text:0:20}"

      # printf '%s %-20s %s\t%s\t%s\n' \
        # "$FZFL_LABEL_WIN" "$text $app_id | $title" "type=WIN" "id=$id"

      emit_line "$FZFL_LABEL_WIN $text $app_id | $title" "type=WIN" "id=$winid" 
      # emit_line "$FZFL_LABEL_WIN $text $app_id | $title" "type=WIN" "id=$id" "title=$title" "app=$app_id" "ws=$ws"


    done < <(jq -c 'sort_by(.order)[]' <<<"$wswindows")

  done < <(printf '%s' "$workspaces" | jq -c 'sort_by(.id)[]')


}

win_focus() {
  local id="$1"
  niri msg action focus-window --id "$id" >/dev/null 2>&1 || true
}

win_jump() {
  local id="$1"
  niri msg action open-overview
  sleep 0.2
  niri msg action focus-window --id $id
  sleep 0.2
  niri msg action close-overview
}


# ---------------------------
# Cache rebuild CLI
# ---------------------------
if [[ "${1:-}" == "--rebuild-cache" ]]; then
  [[ "$FZFL_ENABLE_APPS" == "1" ]] && apps_rebuild_cache
  [[ "$FZFL_ENABLE_HIST" == "1" ]] && history_rebuild_cache
  echo "Rebuilt caches in: $CACHE_DIR"
  exit 0
fi

# ---------------------------
# Build unified list
# ---------------------------
build_list() {
[[ "$FZFL_ENABLE_WIN"  == "1" ]] && source_windows
[[ "$FZFL_ENABLE_APPS" == "1" ]] && source_apps
[[ "$FZFL_ENABLE_WEB"  == "1" ]] && source_web
[[ "$FZFL_ENABLE_CLIP" == "1" ]] && source_clip
[[ "$FZFL_ENABLE_HIST" == "1" ]] && source_history
}



# ---------------------------
# Get the Counts
# ---------------------------

list="$(build_list)"

# Count types
read -r c_win c_app c_web c_clip c_hist < <(
  printf "%s\n" "$list" | awk -F'\t' '
    {
      t="";
      for (i=1; i<=NF; i++) if ($i ~ /^type=/) { t=substr($i,6); break }
      if (t!="") cnt[t]++
    }
    END {
      printf "%d %d %d %d %d\n",
        (cnt["WIN"]+0), (cnt["APP"]+0), (cnt["WEB"]+0), (cnt["CLIP"]+0), (cnt["HIST"]+0)
    }
  '
)

counts="$FZFL_LABEL_WIN:$c_win  $FZFL_LABEL_APPS:$c_app  $FZFL_LABEL_WEB:$c_web  $FZFL_LABEL_CLIP:$c_clip  $FZFL_LABEL_HIST:$c_hist"

# ---------------------------
# fzf bindings
# ---------------------------
# Ctrl-y copies "value" depending on type
# Ctrl-e is handled on Enter for HIST via config (we keep keybinding available for future)
FZF_BINDS=(
  "ctrl-y:execute-silent(echo -n {+} | head -n1 > /tmp/fzfl.sel)+abort"
  "alt-enter:accept"
)

selected="$(
  build_list | fzf \
    --delimiter="$DELIM" --with-nth=1 \
    --smart-case \
    --prompt=">>> " \
    --cycle \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --bind "$(IFS=,; echo "${FZF_BINDS[*]}")" \
    --header $'Enter: run  |  Ctrl-y: copy  |  Alt-Enter: alt action  |  fzfl --help\n'"$counts"
)" || exit 0

# Ctrl-y path: we aborted after writing /tmp/fzfl.sel.
if [[ -f /tmp/fzfl.sel ]]; then
  line="$(cat /tmp/fzfl.sel || true)"
  rm -f /tmp/fzfl.sel || true

  # Copy based on type
  t="$(payload_get "$line" "type" || true)"
  case "$t" in
    WEB)  copy_to_clipboard "$(payload_get "$line" "url" || true)" ;;
    HIST) copy_to_clipboard "$(payload_get "$line" "cmd" || true)" ;;
    APP)  copy_to_clipboard "$(payload_get "$line" "exec" || true)" ;;
    CLIP) clip_restore "$(payload_get "$line" "id" || true)" ;;
    WIN)  copy_to_clipboard "$(payload_get "$line" "title" || true)" ;;
    *)    copy_to_clipboard "$line" ;;
  esac
  exit 0
fi

type="$(payload_get "$selected" "type" || true)"

echo "select=$selected"
echo "type=$type"

# Alt-Enter alternate action:
# We can detect it by checking if user pressed alt-enter? fzf doesn't tell us directly.
# For MVP, treat Alt-Enter as "same selection", but we can add a mode later.
# (If you want, we can implement alt-enter by running a second fzf with actions.)
alt_action=0

case "$type" in

  APP)
    exec_cmd="$(payload_get "$selected" "exec" || true)"
    term="$(payload_get "$selected" "term" || echo 0)"

    if [[ "$alt_action" == "1" ]]; then
      echo "$exec_cmd"
      exit 0
    fi

    # If desktop says Terminal=true, run in terminal; else run detached
    if [[ "$term" == "1" ]]; then
      term_run "$exec_cmd"
    else
      # nohup sh -lc "$exec_cmd" >/dev/null 2>&1 &
      setsid -f sh -lc "$exec_cmd" </dev/null >/dev/null 2>&1 &
      disown 2>/dev/null || true
    fi
    ;;

  WEB)
    url="$(payload_get "$selected" "url" || true)"
    if [[ "$alt_action" == "1" ]]; then
      web_open_tab "$url"
    else
      web_open "$url"
    fi
    ;;

  HIST)
    cmd="$(payload_get "$selected" "cmd" || true)"
    term_run "$cmd"
    ;;

  CLIP)
    id="$(payload_get "$selected" "id" || true)"
    clip_restore "$id"
    ;;

  WIN)
    id="$(payload_get "$selected" "id" || true)"
    echo "id=$id"

    if [[ "$FZFL_WIN_JUMP" == "1" ]]; then 
      win_jump "$id" 
    else
      win_focus "$id"
    fi
    ;;

  *)
    echo "Unknown selection type: $type" >&2
    exit 1
    ;;
esac

# it takes bit of time to disown
sleep 0.1