# utils/helpers.sh
# Common helpers shared by all entry scripts and fzfLauncher.sh.

have() {
  command -v "$1" >/dev/null 2>&1
}

copy_clip() {
  if have wl-copy; then
    printf "%s" "$1" | wl-copy
  elif have xclip; then
    printf "%s" "$1" | xclip -selection clipboard
  fi
}

app_run() {
  setsid nohup bash -lc "$1" >/dev/null 2>&1 & disown
  sleep 0.5
}

run_bg() {
  nohup bash -lc "$1" >/dev/null 2>&1 &
  sleep 0.5
}

open_term() {
  local KEEP_TERM_OPEN=$1
  local cmd="$2"

  local shell="${FZFLAUNCHER_SHELL:-bash}"
  local terminal="${FZFLAUNCHER_TERMINAL:-kitty}"
  local term=()

  case "$terminal" in
    kitty)          term=(kitty -e) ;;
    alacritty)      term=(alacritty -e) ;;
    footclient)     term=(footclient -e) ;;
    gnome-terminal) term=(gnome-terminal -- bash -lc) ;;
    konsole)        term=(konsole -e) ;;
    xterm)          term=(xterm -e) ;;
  esac

  if (( ${#term[@]} == 0 )); then
    if   have kitty;          then term=(kitty -e)
    elif have alacritty;      then term=(alacritty -e)
    elif have footclient;     then term=(footclient -e)
    elif have gnome-terminal; then term=(gnome-terminal -- bash -lc)
    elif have konsole;        then term=(konsole -e)
    else                           term=(xterm -e)
    fi
  fi

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

decorate() {
  local tag="$1"
  awk -F'\t' -v T="$tag" 'NF{printf "%s: %s\t%s\n",T,$1,$2}'
}

pick_fzf_lines() {
  local prompt="$1"

  fzf --with-nth=1 --delimiter=$'\t' --ansi \
      --highlight-line \
      --prompt="$prompt" \
      --preview='echo -e "Command:\n"$(echo {} | cut -f2-)' \
      --preview-window='down,3,wrap'
}
